-- ============================================================================
-- BANCO DE DADOS TRANSACIONAL (OLTP) - REDE DE LIVRARIAS (SQLite)
-- ============================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS vendas;
DROP TABLE IF EXISTS estoque;
DROP TABLE IF EXISTS livros;
DROP TABLE IF EXISTS vendedores;
DROP TABLE IF EXISTS compradores;
DROP TABLE IF EXISTS livrarias;

CREATE TABLE livrarias (
    id_livraria INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    rua TEXT NOT NULL,
    numero TEXT NOT NULL,
    bairro TEXT NOT NULL,
    cidade TEXT NOT NULL,
    complemento TEXT
);

CREATE TABLE vendedores (
    id_vendedor INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    cpf TEXT NOT NULL UNIQUE,
    idade INTEGER NOT NULL,
    id_livraria INTEGER NOT NULL,
    FOREIGN KEY (id_livraria) REFERENCES livrarias(id_livraria)
);

CREATE TABLE compradores (
    id_comprador INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    cpf TEXT NOT NULL UNIQUE,
    idade INTEGER NOT NULL
);

CREATE TABLE livros (
    id_livro INTEGER PRIMARY KEY AUTOINCREMENT,
    titulo TEXT NOT NULL,
    autores TEXT NOT NULL,
    preco REAL NOT NULL,
    editora TEXT NOT NULL,
    condicao TEXT NOT NULL CHECK (condicao IN ('novo', 'usado')),
    ano_publicacao INTEGER NOT NULL
);

CREATE TABLE estoque (
    id_estoque INTEGER PRIMARY KEY AUTOINCREMENT,
    id_livro INTEGER NOT NULL,
    id_livraria INTEGER NOT NULL,
    em_estoque INTEGER NOT NULL CHECK (em_estoque IN (0, 1)),
    quantidade INTEGER NOT NULL DEFAULT 0,
    data_aquisicao TEXT NOT NULL,
    condicao_aquisicao TEXT NOT NULL CHECK (condicao_aquisicao IN ('novo', 'usado')),
    FOREIGN KEY (id_livro) REFERENCES livros(id_livro),
    FOREIGN KEY (id_livraria) REFERENCES livrarias(id_livraria)
);

CREATE TABLE vendas (
    id_venda INTEGER PRIMARY KEY AUTOINCREMENT,
    id_livro INTEGER NOT NULL,
    id_comprador INTEGER NOT NULL,
    id_vendedor INTEGER NULL, -- NULL quando vendido sem intermedio de vendedor
    id_livraria INTEGER NOT NULL,
    data_hora TEXT NOT NULL,
    preco_unitario REAL NOT NULL,
    desconto REAL NOT NULL DEFAULT 0.0,
    FOREIGN KEY (id_livro) REFERENCES livros(id_livro),
    FOREIGN KEY (id_comprador) REFERENCES compradores(id_comprador),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_livraria) REFERENCES livrarias(id_livraria)
);

-- ============================================================================
-- DADOS INICIAIS (SEED OLTP)
-- ============================================================================

INSERT INTO livrarias (nome, rua, numero, bairro, cidade, complemento) VALUES
('Livraria Jardins Aracaju', 'Av. Ministro Geraldo Barreto Sobral', '215', 'Jardins', 'Aracaju', 'Shopping Jardins - Loja 14'),
('Livraria Centro Aracaju', 'Rua João Pessoa', '320', 'Centro', 'Aracaju', 'Galeria Sergipe - Térreo'),
('Livraria Itabaiana', 'Av. Dr. Luiz Magalhães', '780', 'Centro', 'Itabaiana', 'Sala 02'),
('Livraria Lagarto', 'Praça Filomeno Hora', '110', 'Centro', 'Lagarto', NULL);

INSERT INTO vendedores (nome, cpf, idade, id_livraria) VALUES
('Ana Paula Silva', '111.222.333-44', 28, 1),
('Carlos Eduardo Souza', '222.333.444-55', 35, 1),
('Mariana Costa', '333.444.555-66', 24, 2),
('João Pedro Oliveira', '444.555.666-77', 41, 3),
('Fernanda Lima', '555.666.777-88', 30, 4);

INSERT INTO compradores (nome, cpf, idade) VALUES
('Lucas Mendes', '666.777.888-99', 22),
('Beatriz Almeida', '777.888.999-00', 29),
('Rafael Rocha', '888.999.000-11', 37),
('Juliana Ferreira', '999.000.111-22', 45),
('Thiago Martins', '000.111.222-33', 19);

INSERT INTO livros (titulo, autores, preco, editora, condicao, ano_publicacao) VALUES
('Engenharia de Dados na Prática', 'Joe Reis, Matt Housley', 140.00, 'Novatec', 'novo', 2023),
('Designing Data-Intensive Applications', 'Martin Kleppmann', 220.00, 'O''Reilly', 'novo', 2017),
('O Hobbit', 'J.R.R. Tolkien', 45.00, 'HarperCollins', 'usado', 2019),
('Clean Code', 'Robert C. Martin', 95.00, 'Alta Books', 'usado', 2009),
('Dom Casmurro', 'Machado de Assis', 30.00, 'Principis', 'novo', 2020),
('The Data Warehouse Toolkit', 'Ralph Kimball, Margy Ross', 180.00, 'Wiley', 'usado', 2013);

INSERT INTO estoque (id_livro, id_livraria, em_estoque, quantidade, data_aquisicao, condicao_aquisicao) VALUES
(1, 1, 1, 15, '2026-01-10', 'novo'),
(2, 1, 1, 8,  '2026-01-12', 'novo'),
(3, 2, 1, 5,  '2026-01-15', 'usado'),
(4, 2, 1, 3,  '2026-02-01', 'usado'),
(5, 3, 1, 20, '2026-02-05', 'novo'),
(6, 4, 0, 0,  '2026-02-10', 'usado'),
(1, 3, 1, 7,  '2026-03-01', 'novo');

-- Vendas iniciais (Janeiro a Março de 2026) - inclui venda sem vendedor (NULL) e com desconto
INSERT INTO vendas (id_livro, id_comprador, id_vendedor, id_livraria, data_hora, preco_unitario, desconto) VALUES
(1, 1, 1, 1, '2026-01-15 10:30:00', 140.00, 10.00),
(1, 2, 2, 1, '2026-01-18 14:15:00', 140.00, 0.00),
(2, 3, 1, 1, '2026-01-20 16:40:00', 220.00, 20.00),
(3, 4, 3, 2, '2026-02-02 11:05:00', 45.00, 0.00),
(4, 1, NULL, 2, '2026-02-10 18:20:00', 95.00, 5.00),  -- Sem vendedor (autoatendimento/online)
(5, 5, 4, 3, '2026-02-14 09:50:00', 30.00, 0.00),
(1, 3, 4, 3, '2026-03-05 15:10:00', 140.00, 15.00),
(6, 2, 5, 4, '2026-03-12 17:30:00', 180.00, 0.00),
(3, 5, NULL, 2, '2026-03-20 12:00:00', 45.00, 0.00); -- Sem vendedor
