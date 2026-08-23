# Orquestração de Containers com Docker Compose

Este documento explica em detalhes como funciona a orquestração de containers no projeto **Avaliação de Pizzarias**, abordando cada conceito aplicado no `docker-compose.yml`.

---

## 1. Visão Geral

O Docker Compose é a ferramenta utilizada para definir e gerenciar os múltiplos containers da aplicação como uma unidade. Com um único comando (`docker compose up`), toda a infraestrutura é provisionada: banco de dados, API, frontend e reverse proxy.

O arquivo `docker-compose.yml` na raiz do projeto é o manifesto que descreve:

- Quais serviços existem
- Como cada um é construído (imagem)
- As dependências entre eles
- Variáveis de ambiente e secrets
- Healthchecks
- Número de réplicas
- Mapeamento de portas

---

## 2. Serviços Definidos

### 2.1. db (PostgreSQL)

```yaml
db:
  build: ./db
  image: dbimage
  container_name: avalicoes-db
  environment:
    POSTGRES_PASSWORD_FILE: /run/secrets/db_password
  ports:
    - "5432:5432"
  secrets:
    - db_password
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 5s
    timeout: 5s
    retries: 5
```

**Papel:** Banco de dados relacional que armazena todas as avaliações.

- **Build:** Usa o `Dockerfile` em `./db`, que parte de `postgres:16-alpine`, define o banco padrão como `pizzarias` e copia o script `init.sql` para inicialização automática.
- **container_name:** Nome fixo `avalicoes-db` — como há apenas uma instância do banco, faz sentido nomeá-lo explicitamente.
- **Porta exposta:** `5432:5432` — permite acesso externo ao banco para depuração ou ferramentas como DBeaver/pgAdmin.
- **Secret:** A senha é montada via Docker Secrets em `/run/secrets/db_password`, evitando exposição direta.
- **Healthcheck:** Verifica se o PostgreSQL está pronto para aceitar conexões usando `pg_isready`.

### 2.2. api (FastAPI)

```yaml
api:
  build: ./api
  image: apiimage
  environment:
    DB_HOST: db
    DB_PASSWORD_FILE: /run/secrets/db_password
  healthcheck:
    test: ["CMD-SHELL", "curl localhost:8000/health"]
    interval: 5s
    timeout: 5s
    retries: 5
  depends_on:
    db:
      condition: service_healthy
  deploy:
    replicas: 2
  secrets:
    - db_password
```

**Papel:** Camada de API REST que fornece os endpoints para criação e consulta de avaliações.

- **Build:** Usa o `Dockerfile` em `./api`, partindo de `python:3.12-slim`.
- **Variáveis de ambiente:** `DB_HOST=db` faz a API resolver o nome DNS interno do container do banco. A senha é lida do arquivo de secret.
- **depends_on com condition:** A API só inicia **depois** que o banco estiver saudável (`service_healthy`). Isso garante que não haverá erros de conexão na inicialização.
- **Replicas: 2:** O Docker Compose cria 2 instâncias da API para distribuição de carga. O Nginx faz o balanceamento entre elas.
- **Healthcheck:** Verifica a rota `/health` via curl. Se falhar após 5 tentativas, o container é marcado como unhealthy.

### 2.3. frontend (Streamlit)

```yaml
frontend:
  build: ./frontend
  image: frontendimage
  environment:
    API_URL: http://nginx:80/api
  deploy:
    replicas: 3
  depends_on:
    api:
      condition: service_healthy
```

**Papel:** Interface web que permite ao usuário cadastrar e visualizar avaliações.

- **Build:** Usa o `Dockerfile` em `./frontend`, partindo de `python:3.12-slim`.
- **API_URL:** Aponta para o Nginx (`http://nginx:80/api`), que roteia as requisições para as instâncias da API. Assim, o frontend não se comunica diretamente com a API — passa pelo proxy.
- **Replicas: 3:** São criadas 3 instâncias do frontend para alta disponibilidade.
- **depends_on:** Só inicia quando a API estiver saudável.

### 2.4. nginx (Reverse Proxy)

```yaml
nginx:
  build: ./nginx
  container_name: pizzarias-nginx
  ports:
    - "80:80"
  depends_on:
    - api
    - frontend
```

**Papel:** Ponto de entrada único da aplicação. Recebe todas as requisições na porta 80 e as distribui.

- **Build:** Usa o `Dockerfile` em `./nginx`, partindo de `nginx:alpine`.
- **Porta exposta:** `80:80` — única porta acessível externamente para o usuário final.
- **depends_on:** Aguarda que API e frontend estejam criados (sem condition de health aqui, apenas ordem de início).

---

## 3. Conceitos de Orquestração Aplicados

### 3.1. Ordem de Inicialização (depends_on)

O Docker Compose permite definir dependências entre serviços. Neste projeto, a cadeia é:

```
db → api → frontend → nginx
```

Com a opção `condition: service_healthy`, o Compose não apenas espera o container iniciar, mas espera ele **ficar saudável** (healthcheck passando). Isso resolve o problema clássico de a API tentar se conectar ao banco antes dele estar pronto.

### 3.2. Healthchecks

Cada serviço crítico possui um healthcheck:

| Serviço | Comando de Verificação | Intervalo | Tentativas |
|---------|------------------------|:---------:|:----------:|
| db      | `pg_isready -U postgres` | 5s | 5 |
| api     | `curl localhost:8000/health` | 5s | 5 |

O healthcheck permite que o Docker:
1. Monitore o estado real do serviço (não apenas se o processo está rodando)
2. Condicione a inicialização de serviços dependentes
3. Reinicie containers unhealthy (quando combinado com restart policies)

### 3.3. Réplicas e Load Balancing

```yaml
deploy:
  replicas: 2  # api
  replicas: 3  # frontend
```

O `deploy.replicas` cria múltiplas instâncias de um serviço. Quando há réplicas:
- O `container_name` não pode ser usado (cada réplica precisa de um nome único gerado automaticamente)
- O Nginx faz o balanceamento de carga entre as réplicas usando DNS round-robin do Docker

O Nginx está configurado com `upstream` blocks:

```nginx
upstream api_backend {
    server api:8000;
}

upstream frontend_backend {
    server frontend:8501;
}
```

Quando o Nginx resolve `api:8000`, o DNS interno do Docker retorna os IPs de todas as réplicas, distribuindo as requisições entre elas.

### 3.4. Rede Interna (Service Discovery)

O Docker Compose cria automaticamente uma rede bridge para todos os serviços do projeto. Dentro dessa rede:

- Cada serviço pode ser acessado pelo seu **nome** (ex: `db`, `api`, `frontend`, `nginx`)
- A resolução DNS é feita internamente pelo Docker
- Não é necessário configurar IPs — a comunicação é por nome de serviço

Exemplo: a API se conecta ao banco usando `DB_HOST=db`, e o Docker resolve isso para o IP interno do container PostgreSQL.

### 3.5. Docker Secrets

```yaml
secrets:
  db_password:
    file: ./db/password.txt
```

Docker Secrets é o mecanismo seguro para passar informações sensíveis aos containers:

- O conteúdo de `./db/password.txt` é montado em `/run/secrets/db_password` dentro dos containers que declaram acesso
- O arquivo fica disponível apenas em memória (tmpfs), não no filesystem do container
- Tanto o banco quanto a API leem a senha deste arquivo, usando a variável `*_PASSWORD_FILE`

Isso é mais seguro do que usar variáveis de ambiente diretamente, pois:
- Variáveis de ambiente podem ser expostas via `docker inspect`
- Secrets são isolados e acessíveis apenas pelos serviços autorizados

### 3.6. Build de Imagens

Cada serviço tem seu próprio `Dockerfile` e a tag da imagem é definida com `image:`:

```yaml
build: ./api
image: apiimage
```

O Compose constrói a imagem a partir do diretório indicado e a rotula com o nome especificado. Isso permite:
- Reutilizar imagens em outros ambientes
- Identificar facilmente as imagens no registry local (`docker images`)

### 3.7. Mapeamento de Portas

Apenas dois serviços expõem portas para o host:

| Serviço | Mapeamento | Motivo |
|---------|:----------:|--------|
| nginx   | 80:80      | Ponto de entrada para usuários |
| db      | 5432:5432  | Acesso para ferramentas de administração |

Os demais serviços (api, frontend) comunicam-se apenas pela rede interna, sem exposição direta ao host.

---

## 4. Fluxo de uma Requisição

### Requisição do Frontend (navegador)

```
Navegador (localhost:80)
    │
    ▼
Nginx (location /)
    │
    ▼ proxy_pass → frontend:8501
Frontend (Streamlit)
    │
    ▼ requests.post → nginx:80/api/avaliacoes
Nginx (location /api/)
    │
    ▼ proxy_pass → api:8000
API (FastAPI)
    │
    ▼ psycopg2.connect → db:5432
PostgreSQL
```

1. O navegador acessa `http://localhost` (porta 80)
2. O Nginx roteia para uma das réplicas do frontend
3. O Streamlit renderiza a página e, ao enviar dados, faz chamadas HTTP para `http://nginx:80/api`
4. O Nginx intercepta requisições com prefixo `/api/` e encaminha para a API (removendo o prefixo)
5. A API processa a requisição e se comunica com o PostgreSQL

---

## 5. Comandos Úteis

```bash
# Subir todos os serviços com build
docker compose up --build -d

# Ver logs em tempo real
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f api

# Verificar o estado dos containers
docker compose ps

# Escalar um serviço manualmente
docker compose up -d --scale api=4

# Parar e remover todos os containers
docker compose down

# Parar e remover inclusive os volumes (apaga dados do banco)
docker compose down -v

# Rebuild de um serviço específico
docker compose build api
docker compose up -d api
```

---

## 6. Diagrama de Rede

```
┌─────────────────────────────── Docker Network (bridge) ──────────────────────────────┐
│                                                                                       │
│  ┌──────────┐     ┌──────────┐  ┌──────────┐     ┌───────────┐  ┌───────────┐       │
│  │  nginx   │────▶│  api-1   │  │  api-2   │     │frontend-1 │  │frontend-2 │ ...   │
│  │  :80     │────▶│  :8000   │  │  :8000   │     │  :8501    │  │  :8501    │       │
│  └──────────┘     └────┬─────┘  └────┬─────┘     └───────────┘  └───────────┘       │
│       ▲                 │             │                                                │
│       │                 ▼             ▼                                                │
│   Host:80          ┌──────────────────────┐                                           │
│                    │     db (postgres)     │                                           │
│                    │        :5432          │◀── Host:5432                              │
│                    └──────────────────────┘                                           │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Resumo

| Conceito | Aplicação no Projeto |
|----------|---------------------|
| Multi-container | 4 serviços independentes orquestrados juntos |
| depends_on + healthcheck | Garante ordem correta de inicialização |
| Réplicas | API (2x) e Frontend (3x) para alta disponibilidade |
| Reverse Proxy | Nginx como ponto único de entrada e load balancer |
| Docker Secrets | Senha do banco gerenciada de forma segura |
| Service Discovery | Comunicação por nome de serviço via DNS interno |
| Build customizado | Cada serviço com seu Dockerfile e imagem nomeada |
