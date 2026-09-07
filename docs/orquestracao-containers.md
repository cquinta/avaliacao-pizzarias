# Orquestração de Containers

Este documento explica como funciona a orquestração de containers no projeto **Avaliação de Pizzarias**, cobrindo tanto o ambiente local com Docker Compose quanto o cluster com Docker Swarm.

---

## 1. Visão Geral

O projeto suporta dois modos de execução:

| Modo | Arquivo | Uso |
|------|---------|-----|
| Local | `docker-compose.yml` | Desenvolvimento e testes |
| Cluster | `docker-compose-swarm.yml` | Produção em Docker Swarm |

---

## 2. Docker Compose (local)

### 2.1. Serviços

#### db (PostgreSQL)

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

- Banco de dados relacional que armazena todas as avaliações
- A senha é montada via Docker Secrets em `/run/secrets/db_password`
- Healthcheck verifica se o PostgreSQL está pronto com `pg_isready`

#### api (FastAPI)

```yaml
api:
  build: ./api
  image: apiimage
  environment:
    DB_HOST: db
    DB_PASSWORD_FILE: /run/secrets/db_password
  depends_on:
    db:
      condition: service_healthy
  deploy:
    replicas: 2
  secrets:
    - db_password
```

- API REST com 2 réplicas para distribuição de carga
- Só inicia após o banco estar saudável (`service_healthy`)
- Conecta ao banco pelo nome DNS interno `db`

#### frontend (Streamlit)

```yaml
frontend:
  build: ./frontend
  image: frontendimage
  environment:
    API_URL: http://api:8000
  deploy:
    replicas: 3
  depends_on:
    api:
      condition: service_healthy
```

- Interface web com 3 réplicas
- Comunica-se diretamente com a API pelo nome DNS interno `api:8000`
- Só inicia após a API estar saudável

#### nginx (Reverse Proxy)

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

- Ponto de entrada único na porta 80
- Roteia `/api/*` para as réplicas da API e `/*` para as réplicas do frontend

### 2.2. Configuração do Nginx

O `nginx.conf` usa o resolver interno do Docker para evitar problemas de DNS:

```nginx
resolver 127.0.0.11 valid=10s;

upstream api_backend {
    server api:8000;
}

upstream frontend_backend {
    server frontend:8501;
}
```

> O `resolver 127.0.0.11` é necessário especialmente em ambientes EC2, onde o sufixo DNS `.ec2.internal` interfere na resolução dos nomes de serviços do Swarm.

### 2.3. Conceitos aplicados

#### Ordem de inicialização

```
db → api → frontend → nginx
```

Com `condition: service_healthy`, o Compose aguarda o healthcheck passar antes de iniciar o serviço dependente.

#### Réplicas e Load Balancing

O Nginx resolve `api:8000` e `frontend:8501` via DNS round-robin do Docker, distribuindo requisições entre as réplicas automaticamente.

#### Docker Secrets

```yaml
secrets:
  db_password:
    file: ./db/password.txt
```

A senha é montada em `/run/secrets/db_password` dentro dos containers, sem exposição via variáveis de ambiente.

> **Atenção (WSL):** O arquivo `db/password.txt` deve estar dentro do filesystem Linux do WSL (`/home/user/...`). Bind mounts de arquivos no filesystem do Windows (`/mnt/c/...`) causam erros ao montar secrets.

---

## 3. Docker Swarm (cluster)

### 3.1. Diferenças em relação ao Compose local

| Aspecto | Compose local | Swarm |
|---------|--------------|-------|
| Imagens | Build local | Imagens pré-publicadas no registry |
| Redes | bridge | overlay |
| Secrets | Arquivo local | Arquivo local (referenciado no deploy) |
| Placement | N/A | Constraints por role/nó |
| `API_URL` | `http://api:8000` | `http://api:8000` |

### 3.2. Configuração do cluster EC2

#### Portas necessárias no Security Group (self-referencing)

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 2377  | TCP | Gerenciamento do Swarm |
| 7946  | TCP/UDP | Comunicação entre nós |
| 4789  | UDP | Overlay network (VXLAN) |
| 9323  | TCP | Métricas do Docker daemon |
| 8080  | TCP | Métricas do cAdvisor |

> A regra deve ter como origem o próprio Security Group (self-referencing), não um CIDR externo.

#### Métricas do Docker daemon

Em cada nó do cluster, adicione ao `/etc/docker/daemon.json`:

```json
{
  "metrics-addr": "0.0.0.0:9323",
  "experimental": true
}
```

```bash
sudo systemctl restart docker
```

### 3.3. DNS interno no Swarm em EC2

Em ambientes EC2, o sufixo DNS `.ec2.internal` interfere na resolução de nomes de serviços Swarm. O Nginx precisa do `resolver 127.0.0.11` no `nginx.conf` para forçar o uso do DNS interno do Docker.

Sem essa configuração, o Nginx falha com:
```
host not found in upstream "api:8000"
```

### 3.4. Redes overlay e docker_gwbridge

Containers em redes overlay não conseguem alcançar diretamente IPs do host (`10.0.0.x`). Para serviços que precisam acessar portas do host (como o Prometheus acessando a porta 9323 do Docker daemon), o endereço correto é o gateway do `docker_gwbridge`:

```
172.18.0.1  ← gateway padrão do docker_gwbridge
```

---

## 4. Stack de Observabilidade

A stack de observabilidade é definida em `observability-stack/docker-compose-observability.yml` e deployada separadamente.

### 4.1. Serviços

#### prometheus

```yaml
prometheus:
  image: prom/prometheus:latest
  user: root
  volumes:
    - prometheus_data:/prometheus
    - /var/run/docker.sock:/var/run/docker.sock:ro
  ports:
    - "9090:9090"
  configs:
    - source: prometheus_config
      target: /etc/prometheus/prometheus.yml
  deploy:
    replicas: 1
    placement:
      constraints:
        - node.role == manager
```

- Roda exclusivamente no nó manager (acesso ao Docker socket para service discovery)
- Monta o Docker socket para descobrir nós e serviços via Swarm SD
- Roda como `root` para ter permissão de acesso ao socket (grupo `docker`)
- Configuração injetada via Docker Config

#### cadvisor

```yaml
cadvisor:
  image: gcr.io/cadvisor/cadvisor:latest
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /:/rootfs:ro
    - /var/run:/var/run
    - /sys:/sys:ro
    - /var/lib/docker:/var/lib/docker:ro
  ports:
    - target: 8080
      published: 8080
      mode: host
  deploy:
    mode: global
    labels:
      prometheus.job: cadvisor
```

- Roda em modo `global` — uma instância por nó do cluster
- Porta publicada em modo `host` para que o Prometheus acesse pelo IP do nó
- Label `prometheus.job: cadvisor` usado pelo Prometheus para filtrar e nomear o job

### 4.2. Configuração do Prometheus (prometheus.yml)

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: nodes
    relabel_configs:
      - source_labels: [__meta_dockerswarm_node_address]
        target_label: __address__
        replacement: 172.18.0.1:9323
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance

  - job_name: 'dockerswarm'
    dockerswarm_sd_configs:
      - host: unix:///var/run/docker.sock
        role: tasks
    relabel_configs:
      - source_labels: [__meta_dockerswarm_node_address, __meta_dockerswarm_task_port_publish_mode]
        regex: (.+);host
        target_label: __address__
        replacement: $1:8080
      - source_labels: [__meta_dockerswarm_node_hostname]
        target_label: instance
      - source_labels: [__meta_dockerswarm_task_desired_state]
        regex: running
        action: keep
      - source_labels: [__meta_dockerswarm_service_label_prometheus_job]
        regex: .+
        action: keep
      - source_labels: [__meta_dockerswarm_service_label_prometheus_job]
        target_label: job
```

**Job `docker` (métricas do daemon):**
- Descobre todos os nós via Swarm SD
- Substitui o endereço por `172.18.0.1:9323` — o gateway do `docker_gwbridge` que permite ao container Prometheus alcançar a porta 9323 do host

**Job `dockerswarm` (métricas de containers via cAdvisor):**
- Descobre todas as tasks em execução
- Para tasks com `port_publish_mode=host`, substitui o endereço pelo IP do nó host na porta 8080
- Filtra apenas tasks com label `prometheus.job` definido
- Usa o valor do label como nome do job

### 4.3. Deploy

```bash
cd observability-stack
docker stack deploy -c docker-compose-observability.yml obs
```

Para atualizar a configuração do Prometheus:

```bash
docker config rm obs_prometheus_config
docker stack deploy -c docker-compose-observability.yml obs
```

---

## 5. Fluxo de uma Requisição

```
Navegador (porta 80)
    │
    ▼
Nginx (location /)
    │
    ▼ proxy_pass → frontend:8501
Frontend (Streamlit)
    │
    ▼ requests → http://api:8000/avaliacoes
API (FastAPI)
    │
    ▼ psycopg2 → db:5432
PostgreSQL
```

---

## 6. Comandos Úteis

```bash
# Local
docker compose up --build -d
docker compose logs -f
docker compose ps
docker compose down -v

# Swarm — aplicação
docker stack deploy -c docker-compose-swarm.yml demo
docker service ls
docker service logs demo_api --tail 50
docker stack rm demo

# Swarm — observabilidade
docker stack deploy -c observability-stack/docker-compose-observability.yml obs
docker service logs obs_prometheus --tail 30
docker stack rm obs
```
