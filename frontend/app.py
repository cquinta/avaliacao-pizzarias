import os

import requests
import streamlit as st

API_URL = os.getenv("API_URL", "http://api:8000")

st.set_page_config(page_title="Avaliação de Pizzarias", page_icon="🍕")
st.title("🍕 Avaliação de Pizzarias")

# ─── Sidebar com informações do sistema ────────────────────────────────────────

with st.sidebar:
    st.header("Informações do Sistema")

    try:
        resp = requests.get(f"{API_URL}/hostname", timeout=5)
        hostname = resp.json().get("hostname", "N/A")
        st.info(f"**Container:** {hostname}")
    except Exception:
        st.error("Não foi possível obter o hostname")

    try:
        resp = requests.get(f"{API_URL}/version", timeout=5)
        version = resp.json().get("version", "N/A")
        st.info(f"**Versão da API:** {version}")
    except Exception:
        st.error("Não foi possível obter a versão")

    try:
        resp = requests.get(f"{API_URL}/health", timeout=5)
        st.success("API: Saudável ✓")
    except Exception:
        st.error("API: Indisponível ✗")

    try:
        resp = requests.get(f"{API_URL}/health/db", timeout=5)
        if resp.status_code == 200:
            st.success("Banco de Dados: Conectado ✓")
        else:
            st.error("Banco de Dados: Indisponível ✗")
    except Exception:
        st.error("Banco de Dados: Indisponível ✗")

# ─── Formulário de avaliação ───────────────────────────────────────────────────

st.header("Nova Avaliação")

with st.form("form_avaliacao", clear_on_submit=True):
    nome_pizzaria = st.text_input("Nome da Pizzaria", max_chars=100)
    nota = st.slider("Nota", min_value=1, max_value=5, value=3)
    submitted = st.form_submit_button("Enviar Avaliação")

    if submitted:
        if not nome_pizzaria.strip():
            st.error("Por favor, informe o nome da pizzaria.")
        else:
            try:
                resp = requests.post(
                    f"{API_URL}/avaliacoes",
                    json={"nome_pizzaria": nome_pizzaria.strip(), "nota": nota},
                    timeout=5,
                )
                if resp.status_code == 201:
                    st.success("Avaliação registrada com sucesso!")
                else:
                    st.error(f"Erro ao registrar: {resp.text}")
            except Exception as e:
                st.error(f"Erro de conexão com a API: {e}")

# ─── Lista de avaliações ───────────────────────────────────────────────────────

st.header("Avaliações Cadastradas")

try:
    resp = requests.get(f"{API_URL}/avaliacoes", timeout=5)
    if resp.status_code == 200:
        avaliacoes = resp.json()
        if avaliacoes:
            for av in avaliacoes:
                stars = "⭐" * av["nota"]
                st.markdown(f"**{av['nome_pizzaria']}** — {stars} ({av['nota']}/5)")
        else:
            st.info("Nenhuma avaliação cadastrada ainda.")
    else:
        st.error("Erro ao carregar avaliações.")
except Exception as e:
    st.error(f"Erro de conexão com a API: {e}")
