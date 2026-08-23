import os
import socket

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

API_VERSION = "1.0.5"

app = FastAPI(title="Avaliação de Pizzarias", version=API_VERSION)


def get_db_password():
    """Lê a senha do banco via secret file ou variável de ambiente."""
    password_file = os.getenv("DB_PASSWORD_FILE")
    if password_file:
        with open(password_file, "r") as f:
            return f.read().strip()
    return os.getenv("DB_PASSWORD", "postgres")


def get_db_connection():
    """Cria e retorna uma conexão com o PostgreSQL."""
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "db"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "pizzarias"),
        user=os.getenv("DB_USER", "postgres"),
        password=get_db_password(),
    )


# ─── Modelos ───────────────────────────────────────────────────────────────────

class AvaliacaoIn(BaseModel):
    nome_pizzaria: str = Field(..., max_length=100, description="Nome da pizzaria")
    nota: int = Field(..., ge=1, le=5, description="Nota de 1 a 5")


class AvaliacaoOut(BaseModel):
    id: int
    nome_pizzaria: str
    nota: int


# ─── Rotas ─────────────────────────────────────────────────────────────────────

@app.get("/avaliacoes", response_model=list[AvaliacaoOut])
def listar_avaliacoes():
    """Retorna todas as avaliações cadastradas."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, nome_pizzaria, nota FROM avaliacoes ORDER BY id DESC")
            rows = cur.fetchall()
        return [AvaliacaoOut(id=r[0], nome_pizzaria=r[1], nota=r[2]) for r in rows]
    finally:
        conn.close()


@app.post("/avaliacoes", response_model=AvaliacaoOut, status_code=201)
def inserir_avaliacao(avaliacao: AvaliacaoIn):
    """Insere uma nova avaliação no banco de dados."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO avaliacoes (nome_pizzaria, nota) VALUES (%s, %s) RETURNING id",
                (avaliacao.nome_pizzaria, avaliacao.nota),
            )
            new_id = cur.fetchone()[0]
            conn.commit()
        return AvaliacaoOut(id=new_id, nome_pizzaria=avaliacao.nome_pizzaria, nota=avaliacao.nota)
    finally:
        conn.close()


@app.get("/hostname")
def get_hostname():
    """Retorna o hostname do container que está respondendo."""
    return {"hostname": socket.gethostname()}


@app.get("/version")
def get_version():
    """Retorna a versão da API."""
    return {"version": API_VERSION}


@app.get("/health")
def healthcheck():
    """Healthcheck simples da API."""
    return {"status": "healthy"}


@app.get("/health/db")
def healthcheck_db():
    """Healthcheck da conexão com o banco de dados."""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except (psycopg2.OperationalError, psycopg2.InterfaceError) as e:
        raise HTTPException(status_code=503, detail=f"Database unavailable: {e!s}")
