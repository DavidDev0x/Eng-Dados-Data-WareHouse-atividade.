-- ============================================================================
-- CONSULTAS ANALÍTICAS (OLAP) - RESPOSTAS ÀS 6 ANÁLISES DO ENUNCIADO
-- Execute no ClickHouse Play UI: http://localhost:8123/play
-- ============================================================================

-- 1. Livros que estão sendo mais ou menos vendidos, seus preços e localidades onde foram vendidos
SELECT
    l.titulo,
    l.condicao,
    fv.preco_unitario AS preco_vendido,
    liv.cidade,
    liv.nome AS livraria,
    sum(fv.quantidade) AS total_unidades_vendidas,
    sum(fv.valor_liquido) AS receita_liquida
FROM livraria_dw.fato_vendas AS fv
INNER JOIN livraria_dw.dim_livro AS l ON fv.sk_livro = l.sk_livro
INNER JOIN livraria_dw.dim_livraria AS liv ON fv.sk_livraria = liv.sk_livraria
GROUP BY l.titulo, l.condicao, fv.preco_unitario, liv.cidade, liv.nome
ORDER BY total_unidades_vendidas DESC, receita_liquida DESC;

-- 2. Vendedores que mais ou menos vendem (inclui "Sem Vendedor / Venda Direta")
SELECT
    v.nome AS vendedor,
    count() AS qtd_vendas,
    sum(fv.quantidade) AS unidades_vendidas,
    sum(fv.valor_liquido) AS total_faturado
FROM livraria_dw.fato_vendas AS fv
INNER JOIN livraria_dw.dim_vendedor AS v ON fv.sk_vendedor = v.sk_vendedor
GROUP BY v.nome
ORDER BY qtd_vendas DESC, total_faturado DESC;

-- 3. Livrarias que mais ou menos vendem e suas localizações
SELECT
    liv.nome AS livraria,
    liv.cidade,
    liv.bairro,
    count() AS qtd_vendas,
    sum(fv.quantidade) AS unidades_vendidas,
    sum(fv.valor_liquido) AS total_faturado
FROM livraria_dw.fato_vendas AS fv
INNER JOIN livraria_dw.dim_livraria AS liv ON fv.sk_livraria = liv.sk_livraria
GROUP BY liv.nome, liv.cidade, liv.bairro
ORDER BY qtd_vendas DESC, total_faturado DESC;

-- 4. Histórico da mudança de preço dos livros (SCD Tipo 2 em dim_livro)
SELECT
    id_livro_origem,
    titulo,
    condicao,
    preco,
    data_inicio_vigencia,
    data_fim_vigencia,
    if(registro_ativo = 1, 'Ativo', 'Histórico') AS status_versao
FROM livraria_dw.dim_livro
ORDER BY id_livro_origem ASC, data_inicio_vigencia ASC;

-- 5. Histórico do número de vendas por vendedor (ao longo dos meses)
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    v.nome AS vendedor,
    count() AS num_vendas,
    sum(fv.valor_liquido) AS valor_total
FROM livraria_dw.fato_vendas AS fv
INNER JOIN livraria_dw.dim_tempo AS t ON fv.sk_tempo = t.sk_tempo
INNER JOIN livraria_dw.dim_vendedor AS v ON fv.sk_vendedor = v.sk_vendedor
GROUP BY t.ano, t.mes, t.nome_mes, v.nome
ORDER BY t.ano ASC, t.mes ASC, num_vendas DESC;

-- 6. Histórico do número de vendas por livraria e suas localidades (ao longo dos meses)
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    liv.nome AS livraria,
    liv.cidade,
    count() AS num_vendas,
    sum(fv.valor_liquido) AS valor_total
FROM livraria_dw.fato_vendas AS fv
INNER JOIN livraria_dw.dim_tempo AS t ON fv.sk_tempo = t.sk_tempo
INNER JOIN livraria_dw.dim_livraria AS liv ON fv.sk_livraria = liv.sk_livraria
GROUP BY t.ano, t.mes, t.nome_mes, liv.nome, liv.cidade
ORDER BY t.ano ASC, t.mes ASC, num_vendas DESC;
