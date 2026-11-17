"""
ETL completo: Cria/popula o banco transacional (OLTP SQLite), cria o esquema do
Data Warehouse no ClickHouse, executa a carga inicial e demonstra uma atualização
SCD Tipo 2 (mudança de preço de livros) com novas vendas.
"""

from datetime import datetime
import json
from pathlib import Path
import sqlite3
import urllib.parse
import urllib.request

BASE_DIR = Path(__file__).resolve().parent.parent
OLTP_DB_PATH = BASE_DIR / "livraria_oltp.db"
OLTP_SQL_PATH = BASE_DIR / "sql" / "01_oltp_schema_seed.sql"
DW_SQL_PATH = BASE_DIR / "sql" / "02_dw_schema.sql"

CH_URL = "http://localhost:8123/"
CH_USER = "admin"
CH_PASS = "admin123"

MESES_PT = {
    1: "Janeiro", 2: "Fevereiro", 3: "Março", 4: "Abril",
    5: "Maio", 6: "Junho", 7: "Julho", 8: "Agosto",
    9: "Setembro", 10: "Outubro", 11: "Novembro", 12: "Dezembro",
}

DIAS_SEMANA_PT = {
    0: "Segunda-feira", 1: "Terça-feira", 2: "Quarta-feira", 3: "Quinta-feira",
    4: "Sexta-feira", 5: "Sábado", 6: "Domingo",
}


def ch_execute(query: str, data: str | None = None) -> str:
    """Executa uma instrução SQL ou inserção JSONEachRow no ClickHouse via HTTP."""
    params = urllib.parse.urlencode({"query": query, "mutations_sync": "1"})
    url = f"{CH_URL}?{params}"
    body = data.encode("utf-8") if data is not None else b""
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("X-ClickHouse-User", CH_USER)
    req.add_header("X-ClickHouse-Key", CH_PASS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8").strip()


def ch_insert_json(table: str, rows: list[dict]) -> None:
    """Insere lista de dicionários em uma tabela do ClickHouse usando JSONEachRow."""
    if not rows:
        return
    payload = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows)
    ch_execute(f"INSERT INTO {table} FORMAT JSONEachRow", payload)


def init_oltp() -> sqlite3.Connection:
    """Cria e popula o banco OLTP SQLite a partir do script SQL."""
    if OLTP_DB_PATH.exists():
        OLTP_DB_PATH.unlink()
    conn = sqlite3.connect(OLTP_DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript(OLTP_SQL_PATH.read_text(encoding="utf-8"))
    conn.commit()
    return conn


def reset_dw_schema() -> None:
    """Recria o banco e tabelas do Data Warehouse no ClickHouse."""
    ch_execute("DROP DATABASE IF EXISTS livraria_dw")
    ddl_script = DW_SQL_PATH.read_text(encoding="utf-8")
    # Remove comentários de linha e executa cada comando separado por ';'
    linhas = [
        linha for linha in ddl_script.splitlines()
        if not linha.strip().startswith("--")
    ]
    comandos = [c.strip() for c in "\n".join(linhas).split(";") if c.strip()]
    for cmd in comandos:
        ch_execute(cmd)


def build_tempo_row(dt: datetime, sk_tempo: int) -> dict:
    """Constrói registro para dim_tempo a partir de um datetime."""
    return {
        "sk_tempo": sk_tempo,
        "data_completa": dt.strftime("%Y-%m-%d"),
        "hora": dt.hour,
        "dia": dt.day,
        "mes": dt.month,
        "nome_mes": MESES_PT[dt.month],
        "trimestre": (dt.month - 1) // 3 + 1,
        "ano": dt.year,
        "dia_semana": DIAS_SEMANA_PT[dt.weekday()],
    }


def main() -> None:
    print("1. Criando e populando banco transacional (OLTP)...")
    oltp = init_oltp()

    print("2. Criando esquema do Data Warehouse no ClickHouse...")
    reset_dw_schema()

    # --- Dimensão Livraria ---
    livrarias = oltp.execute("SELECT * FROM livrarias").fetchall()
    dim_livraria_rows = []
    map_livraria = {}
    for idx, row in enumerate(livrarias, start=1):
        map_livraria[row["id_livraria"]] = idx
        dim_livraria_rows.append({
            "sk_livraria": idx,
            "id_livraria_origem": row["id_livraria"],
            "nome": row["nome"],
            "rua": row["rua"],
            "numero": row["numero"],
            "bairro": row["bairro"],
            "cidade": row["cidade"],
            "complemento": row["complemento"] or "",
        })
    ch_insert_json("livraria_dw.dim_livraria", dim_livraria_rows)

    # --- Dimensão Vendedor (sk_vendedor = 0 para vendas sem vendedor) ---
    vendedores = oltp.execute("SELECT * FROM vendedores").fetchall()
    dim_vendedor_rows = [{
        "sk_vendedor": 0,
        "id_vendedor_origem": 0,
        "nome": "Sem Vendedor (Venda Direta)",
        "cpf": "000.000.000-00",
        "idade": 0,
    }]
    map_vendedor = {None: 0}
    for idx, row in enumerate(vendedores, start=1):
        map_vendedor[row["id_vendedor"]] = idx
        dim_vendedor_rows.append({
            "sk_vendedor": idx,
            "id_vendedor_origem": row["id_vendedor"],
            "nome": row["nome"],
            "cpf": row["cpf"],
            "idade": row["idade"],
        })
    ch_insert_json("livraria_dw.dim_vendedor", dim_vendedor_rows)

    # --- Dimensão Comprador ---
    compradores = oltp.execute("SELECT * FROM compradores").fetchall()
    dim_comprador_rows = []
    map_comprador = {}
    for idx, row in enumerate(compradores, start=1):
        map_comprador[row["id_comprador"]] = idx
        dim_comprador_rows.append({
            "sk_comprador": idx,
            "id_comprador_origem": row["id_comprador"],
            "nome": row["nome"],
            "cpf": row["cpf"],
            "idade": row["idade"],
        })
    ch_insert_json("livraria_dw.dim_comprador", dim_comprador_rows)

    # --- Dimensão Livro (Carga Inicial - SCD Tipo 2) ---
    livros = oltp.execute("SELECT * FROM livros").fetchall()
    dim_livro_rows = []
    map_livro_ativo = {}
    next_sk_livro = 1
    for row in livros:
        sk = next_sk_livro
        next_sk_livro += 1
        map_livro_ativo[row["id_livro"]] = sk
        dim_livro_rows.append({
            "sk_livro": sk,
            "id_livro_origem": row["id_livro"],
            "titulo": row["titulo"],
            "autores": row["autores"],
            "editora": row["editora"],
            "ano_publicacao": row["ano_publicacao"],
            "condicao": row["condicao"],
            "preco": round(row["preco"], 2),
            "data_inicio_vigencia": "2026-01-01 00:00:00",
            "data_fim_vigencia": None,
            "registro_ativo": 1,
        })
    ch_insert_json("livraria_dw.dim_livro", dim_livro_rows)

    # --- Dimensão Tempo + Fato Vendas + Fato Estoque (Carga Inicial) ---
    map_tempo: dict[tuple[str, int], int] = {}
    dim_tempo_rows: list[dict] = []
    next_sk_tempo = 1

    def get_or_create_sk_tempo(dt: datetime) -> int:
        nonlocal next_sk_tempo
        key = (dt.strftime("%Y-%m-%d"), dt.hour)
        if key not in map_tempo:
            sk = next_sk_tempo
            next_sk_tempo += 1
            map_tempo[key] = sk
            dim_tempo_rows.append(build_tempo_row(dt, sk))
        return map_tempo[key]

    vendas_iniciais = oltp.execute("SELECT * FROM vendas").fetchall()
    fato_vendas_rows = []
    for idx, v in enumerate(vendas_iniciais, start=1):
        dt = datetime.strptime(v["data_hora"], "%Y-%m-%d %H:%M:%S")
        sk_t = get_or_create_sk_tempo(dt)
        liquido = round(v["preco_unitario"] - v["desconto"], 2)
        fato_vendas_rows.append({
            "sk_venda": idx,
            "sk_tempo": sk_t,
            "sk_livro": map_livro_ativo[v["id_livro"]],
            "sk_livraria": map_livraria[v["id_livraria"]],
            "sk_vendedor": map_vendedor[v["id_vendedor"]],
            "sk_comprador": map_comprador[v["id_comprador"]],
            "data_hora": v["data_hora"],
            "quantidade": 1,
            "preco_unitario": round(v["preco_unitario"], 2),
            "valor_desconto": round(v["desconto"], 2),
            "valor_liquido": liquido,
        })

    estoques = oltp.execute("SELECT * FROM estoque").fetchall()
    fato_estoque_rows = []
    for idx, e in enumerate(estoques, start=1):
        dt = datetime.strptime(e["data_aquisicao"], "%Y-%m-%d")
        sk_t = get_or_create_sk_tempo(dt)
        fato_estoque_rows.append({
            "sk_estoque": idx,
            "sk_tempo": sk_t,
            "sk_livro": map_livro_ativo[e["id_livro"]],
            "sk_livraria": map_livraria[e["id_livraria"]],
            "em_estoque": e["em_estoque"],
            "condicao_aquisicao": e["condicao_aquisicao"],
            "quantidade_adicionada": e["quantidade"],
        })

    ch_insert_json("livraria_dw.dim_tempo", dim_tempo_rows)
    ch_insert_json("livraria_dw.fato_vendas", fato_vendas_rows)
    ch_insert_json("livraria_dw.fato_estoque", fato_estoque_rows)
    print(f"   Carga inicial concluída: {len(fato_vendas_rows)} vendas e {len(fato_estoque_rows)} registros de estoque.")

    # =========================================================================
    # ETAPA 2: SIMULAÇÃO DE MUDANÇA DE PREÇO (SCD TIPO 2) E NOVAS VENDAS
    # =========================================================================
    print("3. Simulando alteração de preços no OLTP e aplicando SCD Tipo 2 no DW...")
    data_mudanca = "2026-04-01 00:00:00"
    alteracoes_preco = [
        (1, 155.00),  # "Engenharia de Dados na Prática" sobe de 140 para 155
        (3, 39.90),   # "O Hobbit" (usado) cai de 45 para 39.90
    ]

    novas_versoes_livro = []
    for id_livro, novo_preco in alteracoes_preco:
        oltp.execute("UPDATE livros SET preco = ? WHERE id_livro = ?", (novo_preco, id_livro))
        # Fecha a versão anterior no DW
        ch_execute(
            f"ALTER TABLE livraria_dw.dim_livro "
            f"UPDATE data_fim_vigencia = '{data_mudanca}', registro_ativo = 0 "
            f"WHERE id_livro_origem = {id_livro} AND registro_ativo = 1"
        )
        # Insere nova versão ativa no DW
        livro = oltp.execute("SELECT * FROM livros WHERE id_livro = ?", (id_livro,)).fetchone()
        novo_sk = next_sk_livro
        next_sk_livro += 1
        map_livro_ativo[id_livro] = novo_sk
        novas_versoes_livro.append({
            "sk_livro": novo_sk,
            "id_livro_origem": livro["id_livro"],
            "titulo": livro["titulo"],
            "autores": livro["autores"],
            "editora": livro["editora"],
            "ano_publicacao": livro["ano_publicacao"],
            "condicao": livro["condicao"],
            "preco": round(novo_preco, 2),
            "data_inicio_vigencia": data_mudanca,
            "data_fim_vigencia": None,
            "registro_ativo": 1,
        })
    oltp.commit()
    ch_insert_json("livraria_dw.dim_livro", novas_versoes_livro)

    # Insere novas vendas em Abril e Maio de 2026 já com os novos preços
    novas_vendas = [
        (1, 4, 1, 1, "2026-04-05 11:20:00", 155.00, 0.00),
        (3, 2, 3, 2, "2026-04-12 15:45:00", 39.90, 0.00),
        (1, 5, 2, 1, "2026-05-03 10:10:00", 155.00, 15.00),
        (3, 1, NULL_VAL := None, 2, "2026-05-10 19:00:00", 39.90, 0.00),
        (2, 3, 5, 4, "2026-05-14 14:30:00", 220.00, 10.00),
    ]
    oltp.executemany(
        "INSERT INTO vendas (id_livro, id_comprador, id_vendedor, id_livraria, data_hora, preco_unitario, desconto) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        novas_vendas,
    )
    oltp.commit()

    novos_tempos = []
    novos_fatos = []
    next_sk_venda = len(fato_vendas_rows) + 1
    vendas_recentes = oltp.execute(
        "SELECT * FROM vendas WHERE id_venda > ?", (len(fato_vendas_rows),)
    ).fetchall()

    for v in vendas_recentes:
        dt = datetime.strptime(v["data_hora"], "%Y-%m-%d %H:%M:%S")
        key = (dt.strftime("%Y-%m-%d"), dt.hour)
        if key not in map_tempo:
            sk_t = next_sk_tempo
            next_sk_tempo += 1
            map_tempo[key] = sk_t
            novos_tempos.append(build_tempo_row(dt, sk_t))
        else:
            sk_t = map_tempo[key]

        novos_fatos.append({
            "sk_venda": next_sk_venda,
            "sk_tempo": sk_t,
            "sk_livro": map_livro_ativo[v["id_livro"]],
            "sk_livraria": map_livraria[v["id_livraria"]],
            "sk_vendedor": map_vendedor[v["id_vendedor"]],
            "sk_comprador": map_comprador[v["id_comprador"]],
            "data_hora": v["data_hora"],
            "quantidade": 1,
            "preco_unitario": round(v["preco_unitario"], 2),
            "valor_desconto": round(v["desconto"], 2),
            "valor_liquido": round(v["preco_unitario"] - v["desconto"], 2),
        })
        next_sk_venda += 1

    ch_insert_json("livraria_dw.dim_tempo", novos_tempos)
    ch_insert_json("livraria_dw.fato_vendas", novos_fatos)
    oltp.close()

    total_vendas = ch_execute("SELECT count() FROM livraria_dw.fato_vendas")
    total_livros_scd = ch_execute("SELECT count() FROM livraria_dw.dim_livro")
    print(f"   ETL finalizado! Total em fato_vendas: {total_vendas} | Versões em dim_livro (SCD2): {total_livros_scd}")
    print("4. Acesse http://localhost:8123/play (usuário: admin / senha: admin123) para rodar as consultas!")


if __name__ == "__main__":
    main()
