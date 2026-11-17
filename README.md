# Atividade 5 – Data Warehouse (Rede de Livrarias)

Projeto completo de Data Warehouse utilizando **ClickHouse** (via Docker) para modelagem multidimensional em **Constelação de Fatos (Galaxy Schema)** com **SCD Tipo 2** para histórico de preços, alimentado a partir de um banco transacional (**OLTP** em SQLite) via script **ETL** em Python.

---

## Modelo Multidimensional (Constelação de Fatos)

```mermaid
erDiagram
    dim_tempo {
        UInt32 sk_tempo PK
        Date data_completa
        UInt8 hora
        UInt8 dia
        UInt8 mes
        String nome_mes
        UInt8 trimestre
        UInt16 ano
        String dia_semana
    }

    dim_livro {
        UInt32 sk_livro PK
        UInt32 id_livro_origem
        String titulo
        String autores
        String editora
        UInt16 ano_publicacao
        String condicao
        Decimal preco
        DateTime data_inicio_vigencia
        DateTime data_fim_vigencia
        UInt8 registro_ativo
    }

    dim_livraria {
        UInt32 sk_livraria PK
        UInt32 id_livraria_origem
        String nome
        String rua
        String numero
        String bairro
        String cidade
        String complemento
    }

    dim_vendedor {
        UInt32 sk_vendedor PK
        UInt32 id_vendedor_origem
        String nome
        String cpf
        UInt8 idade
    }

    dim_comprador {
        UInt32 sk_comprador PK
        UInt32 id_comprador_origem
        String nome
        String cpf
        UInt8 idade
    }

    fato_vendas {
        UInt32 sk_venda PK
        UInt32 sk_tempo FK
        UInt32 sk_livro FK
        UInt32 sk_livraria FK
        UInt32 sk_vendedor FK
        UInt32 sk_comprador FK
        DateTime data_hora
        UInt16 quantidade
        Decimal preco_unitario
        Decimal valor_desconto
        Decimal valor_liquido
    }

    fato_estoque {
        UInt32 sk_estoque PK
        UInt32 sk_tempo FK
        UInt32 sk_livro FK
        UInt32 sk_livraria FK
        UInt8 em_estoque
        String condicao_aquisicao
        UInt16 quantidade_adicionada
    }

    dim_tempo ||--o{ fato_vendas : "sk_tempo"
    dim_livro ||--o{ fato_vendas : "sk_livro"
    dim_livraria ||--o{ fato_vendas : "sk_livraria"
    dim_vendedor ||--o{ fato_vendas : "sk_vendedor"
    dim_comprador ||--o{ fato_vendas : "sk_comprador"

    dim_tempo ||--o{ fato_estoque : "sk_tempo"
    dim_livro ||--o{ fato_estoque : "sk_livro"
    dim_livraria ||--o{ fato_estoque : "sk_livraria"
```

---

## Como Executar

### 1. Subir o ClickHouse (Tarefa 1)
```powershell
docker compose up -d
```

### 2. Criar OLTP, Criar DW e Executar ETL (Tarefas 3 e 4)
```powershell
python scripts/etl_carga_dw.py
```

### 3. Executar Consultas Analíticas na Interface Web do ClickHouse
Acesse no navegador: **http://localhost:8123/play**
- **Usuário:** `admin`
- **Senha:** `admin123`

Cole e execute as consultas de [`sql/03_consultas_analiticas.sql`](sql/03_consultas_analiticas.sql).

---

## Estrutura do Projeto
- `docker-compose.yml` — Container do ClickHouse Server.
- `sql/01_oltp_schema_seed.sql` — Banco transacional (OLTP) da rede de livrarias + dados iniciais.
- `sql/02_dw_schema.sql` — DDL do Data Warehouse no ClickHouse (`livraria_dw`).
- `scripts/etl_carga_dw.py` — Script ETL (extração do OLTP, carga inicial e atualização SCD Tipo 2).
- `sql/03_consultas_analiticas.sql` — Consultas respondendo às 6 perguntas de negócio do enunciado.
- `ROTEIRO_VIDEO.md` — Roteiro cronometrado para a gravação do vídeo de até 5 minutos.
