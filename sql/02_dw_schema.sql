-- ============================================================================
-- DATA WAREHOUSE (OLAP) - CLICKHOUSE - MODELO CONSTELAÇÃO DE FATOS
-- ============================================================================

CREATE DATABASE IF NOT EXISTS livraria_dw;

-- 1. Dimensão Tempo
CREATE TABLE IF NOT EXISTS livraria_dw.dim_tempo
(
    sk_tempo UInt32,
    data_completa Date,
    hora UInt8,
    dia UInt8,
    mes UInt8,
    nome_mes String,
    trimestre UInt8,
    ano UInt16,
    dia_semana String
)
ENGINE = MergeTree()
ORDER BY sk_tempo;

-- 2. Dimensão Livro (SCD Tipo 2 - preserva histórico de mudança de preços)
CREATE TABLE IF NOT EXISTS livraria_dw.dim_livro
(
    sk_livro UInt32,
    id_livro_origem UInt32,
    titulo String,
    autores String,
    editora String,
    ano_publicacao UInt16,
    condicao LowCardinality(String), -- 'novo' ou 'usado'
    preco Decimal(10, 2),
    data_inicio_vigencia DateTime,
    data_fim_vigencia Nullable(DateTime),
    registro_ativo UInt8 -- 1 = ativo, 0 = histórico
)
ENGINE = MergeTree()
ORDER BY (id_livro_origem, sk_livro);

-- 3. Dimensão Livraria
CREATE TABLE IF NOT EXISTS livraria_dw.dim_livraria
(
    sk_livraria UInt32,
    id_livraria_origem UInt32,
    nome String,
    rua String,
    numero String,
    bairro String,
    cidade String,
    complemento String
)
ENGINE = MergeTree()
ORDER BY sk_livraria;

-- 4. Dimensão Vendedor (inclui sk_vendedor = 0 para "Sem Vendedor / Venda Direta")
CREATE TABLE IF NOT EXISTS livraria_dw.dim_vendedor
(
    sk_vendedor UInt32,
    id_vendedor_origem UInt32,
    nome String,
    cpf String,
    idade UInt8
)
ENGINE = MergeTree()
ORDER BY sk_vendedor;

-- 5. Dimensão Comprador
CREATE TABLE IF NOT EXISTS livraria_dw.dim_comprador
(
    sk_comprador UInt32,
    id_comprador_origem UInt32,
    nome String,
    cpf String,
    idade UInt8
)
ENGINE = MergeTree()
ORDER BY sk_comprador;

-- 6. Tabela de Fatos: Vendas
CREATE TABLE IF NOT EXISTS livraria_dw.fato_vendas
(
    sk_venda UInt32,
    sk_tempo UInt32,
    sk_livro UInt32,
    sk_livraria UInt32,
    sk_vendedor UInt32,
    sk_comprador UInt32,
    data_hora DateTime,
    quantidade UInt16,
    preco_unitario Decimal(10, 2),
    valor_desconto Decimal(10, 2),
    valor_liquido Decimal(10, 2)
)
ENGINE = MergeTree()
ORDER BY (sk_tempo, sk_livraria, sk_livro, sk_venda);

-- 7. Tabela de Fatos: Entradas no Estoque (Constelação de Fatos)
CREATE TABLE IF NOT EXISTS livraria_dw.fato_estoque
(
    sk_estoque UInt32,
    sk_tempo UInt32,
    sk_livro UInt32,
    sk_livraria UInt32,
    em_estoque UInt8,
    condicao_aquisicao LowCardinality(String),
    quantidade_adicionada UInt16
)
ENGINE = MergeTree()
ORDER BY (sk_tempo, sk_livraria, sk_livro, sk_estoque);
