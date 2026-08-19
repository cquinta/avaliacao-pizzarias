CREATE TABLE IF NOT EXISTS avaliacoes (
    id SERIAL PRIMARY KEY,
    nome_pizzaria VARCHAR(100) NOT NULL,
    nota INTEGER NOT NULL CHECK (nota >= 1 AND nota <= 5)
);

INSERT INTO avaliacoes (nome_pizzaria, nota) VALUES
    ('Bráz Pizzaria', 5),
    ('Pizzaria Camelo', 4),
    ('Capricciosa', 5);
