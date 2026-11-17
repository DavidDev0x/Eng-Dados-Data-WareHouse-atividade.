# Roteiro de Vídeo (Máximo 5 minutos) — Atividade 5: Data Warehouse

> **Lembrete de Entrega (SIGAA):**
> - Trabalho em grupo de **2 ou 3 pessoas** (grupos de 1 ou >3 têm desconto mínimo de 50%).
> - Enviar **um `.zip`** (vídeo + `.txt` com nome completo e matrícula dos integrantes) **OU** **um `.txt`** contendo o link do vídeo hospedado + nome completo e matrícula dos integrantes.

---

## Cronograma Sugerido (4m30s total — margem segura abaixo de 5m)

### 0:00 – 0:45 | Tarefa 1: Instalação da Ferramenta (ClickHouse)
- **Na tela:** Terminal com `docker-compose.yml` aberto.
- **Fala:** Explicar que a ferramenta escolhida para o Data Warehouse é o **ClickHouse** (banco colunar OLAP), instalado via Docker (`docker compose up -d`), e mostrar o container rodando (`docker ps`) e a interface web acessível em `http://localhost:8123/play`.

### 0:45 – 2:00 | Tarefa 2: Projeto Multidimensional e Banco OLTP
- **Na tela:** Diagrama Mermaid no `README.md` e `sql/01_oltp_schema_seed.sql`.
- **Fala:**
  - Mostrar rapidamente as tabelas do banco transacional (**OLTP**): `livrarias`, `vendedores`, `compradores`, `livros`, `estoque` e `vendas` (destacando `id_vendedor NULL` para vendas sem vendedor).
  - Explicar o modelo multidimensional em **Constelação de Fatos**:
    - 2 tabelas de fatos: `fato_vendas` e `fato_estoque`.
    - 5 dimensões compartilhadas: `dim_tempo`, `dim_livro`, `dim_livraria`, `dim_vendedor` (com `sk_vendedor = 0` para venda direta sem vendedor) e `dim_comprador`.
    - Destacar o **SCD Tipo 2** na `dim_livro` (`data_inicio_vigencia`, `data_fim_vigencia`, `registro_ativo`) para guardar o histórico de mudança de preço.

### 2:00 – 3:00 | Tarefa 3: Criação do Armazém de Dados
- **Na tela:** `sql/02_dw_schema.sql` e execução do `python scripts/etl_carga_dw.py`.
- **Fala:** Mostrar a criação do banco `livraria_dw` e das tabelas no ClickHouse usando `MergeTree()` e executar o script ETL que cria o OLTP, o DW, faz a carga inicial e simula uma alteração de preço com novas vendas.

### 3:00 – 4:30 | Tarefa 4: Inserção de Dados e Consultas Analíticas
- **Na tela:** ClickHouse Play UI (`http://localhost:8123/play`) com as consultas de `sql/03_consultas_analiticas.sql`.
- **Fala:** Rodar e mostrar o resultado de cada uma das **6 análises**:
  1. Livros mais/menos vendidos, preços e localidades;
  2. Vendedores que mais/menos vendem (mostrando também "Sem Vendedor");
  3. Livrarias que mais/menos vendem e cidades;
  4. Histórico de mudança de preço dos livros (`dim_livro` SCD Tipo 2);
  5. Histórico de vendas por vendedor ao longo dos meses;
  6. Histórico de vendas por livraria e localidade ao longo dos meses.
