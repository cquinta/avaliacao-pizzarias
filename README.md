# 🍕 Avaliação de Pizzarias

Sistema web para avaliação de pizzarias, construído com uma arquitetura de microsserviços containerizados usando Docker Compose.

## Arquitetura

O projeto é composto por 4 serviços que se comunicam em uma rede Docker interna:

```
┌────────────────────────────────────────────────────┐
│                   Navegador                         │
│                  (porta 80)                         │
└──────────────────────┬─────────────────────────────┘
                       │
              ┌────────▼────────┐
              │      Nginx      │
              │  (Reverse Proxy)│
              └───┬─────────┬───┘
                  │         │
       /api/*     │         │  /*
                  │         │
        ┌─────────▼──┐  ┌──▼──────────┐
        │   API (x2) │  │Frontend (x3)│
        │  FastAPI    │  │  Streamlit  │
        └──────┬──────┘  └─────────────┘
               │
        ┌──────▼──────┐
        │  PostgreSQL  │
        │   (banco)    │
        └─────────────┘
```

| Serviço    | Tecnologia          | Porta Interna | Réplicas |
|------------|---------------------|:-------------:|:--------:|
| **db**     | PostgreSQL 16       | 5432          | 1        |
| **api**    | FastAPI + Uvicorn   | 8000          | 2        |
| **frontend** | Streamlit         | 8501          | 3        |
| **nginx**  | Nginx Alpine        | 80            | 1        |

## Funcionalidades

- Cadastrar avaliações de pizzarias com nota de 1 a 5
- Listar todas as avaliações cadastradas com exibição de estrelas
- Healthcheck da API e do banco de dados
- Exibição do hostname do container (útil para visualizar o load balancing)
- Exibição da versão da API

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)

## Como executar

1. Clone o repositório:

```bash
git clone <url-do-repositorio>
cd avaliacao-pizzarias
```

2. Suba todos os serviços:

```bash
docker compose up --build -d
```

3. Acesse a aplicação no navegador:

```
http://localhost
```

Para encerrar:

```bash
docker compose down
```

## Estrutura do Projeto

```
avaliacao-pizzarias/
├── api/
│   ├── Dockerfile
│   ├── main.py              # API FastAPI com rotas REST
│   └── requirements.txt
├── db/
│   ├── Dockerfile
│   ├── init.sql             # Script de criação de tabelas e dados iniciais
│   └── password.txt         # Senha do banco (Docker Secret)
├── frontend/
│   ├── Dockerfile
│   ├── app.py               # Interface Streamlit
│   └── requirements.txt
├── nginx/
│   ├── Dockerfile
│   └── nginx.conf           # Configuração de reverse proxy
├── docker-compose.yml
├── LICENSE
└── README.md
```

## Endpoints da API

| Método | Rota           | Descrição                          |
|--------|----------------|------------------------------------|
| GET    | /avaliacoes    | Lista todas as avaliações          |
| POST   | /avaliacoes    | Cria uma nova avaliação            |
| GET    | /hostname      | Retorna o hostname do container    |
| GET    | /version       | Retorna a versão da API            |
| GET    | /health        | Healthcheck da API                 |
| GET    | /health/db     | Healthcheck da conexão com o banco |

### Exemplo de payload para criar avaliação

```json
{
  "nome_pizzaria": "Pizzaria Exemplo",
  "nota": 4
}
```

## Tecnologias Utilizadas

- **Python 3.12** — linguagem principal
- **FastAPI 0.111** — framework da API REST
- **Uvicorn 0.30** — servidor ASGI
- **Streamlit 1.36** — interface web interativa
- **PostgreSQL 16** — banco de dados relacional
- **Nginx** — reverse proxy e load balancer
- **Docker / Docker Compose** — containerização e orquestração

## Segurança

A senha do banco de dados é gerenciada via **Docker Secrets** (arquivo `db/password.txt`), evitando expor credenciais em variáveis de ambiente diretamente no `docker-compose.yml`.

## Licença

Este projeto está licenciado sob a [Apache License 2.0](LICENSE).
