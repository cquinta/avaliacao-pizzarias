# 🍕 Avaliação de Pizzarias

Sistema web para avaliação de pizzarias, construído com uma arquitetura de microsserviços containerizados usando Docker Compose e Docker Swarm.

## Arquitetura

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

| Serviço      | Tecnologia        | Porta Interna | Réplicas |
|--------------|-------------------|:-------------:|:--------:|
| **db**       | PostgreSQL 16     | 5432          | 1        |
| **api**      | FastAPI + Uvicorn | 8000          | 2        |
| **frontend** | Streamlit         | 8501          | 3        |
| **nginx**    | Nginx Alpine      | 80            | 1        |

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

### Localmente (Docker Compose)

> **Atenção (WSL):** O projeto deve estar dentro do filesystem Linux do WSL (`/home/user/...`), não em `/mnt/c/...`. Bind mounts de arquivos no filesystem do Windows causam erros com Docker Secrets.

1. Clone o repositório:

```bash
git clone <url-do-repositorio>
cd avaliacao-pizzarias
```

2. Suba todos os serviços:

```bash
docker compose up --build -d
```

3. Acesse a aplicação:

```
http://localhost
```

Para encerrar:

```bash
docker compose down
```

### Docker Swarm (EC2 / produção)

#### Pré-requisitos no cluster

1. Inicialize o Swarm no nó manager:

```bash
docker swarm init
```

2. Adicione os workers ao cluster:

```bash
docker swarm join --token <token> <ip-manager>:2377
```

3. Configure o Docker daemon em **cada nó** para expor métricas (necessário para observabilidade):

```bash
echo '{"metrics-addr": "0.0.0.0:9323", "experimental": true}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

4. Libere as seguintes portas no Security Group (regra **self-referencing** entre instâncias do cluster):

| Porta | Protocolo | Uso |
|-------|-----------|-----|
| 2377  | TCP | Gerenciamento do Swarm |
| 7946  | TCP/UDP | Comunicação entre nós |
| 4789  | UDP | Overlay network (VXLAN) |
| 9323  | TCP | Métricas do Docker daemon |
| 8080  | TCP | Métricas do cAdvisor |
| 9090  | TCP | Prometheus (acesso externo) |

#### Deploy da aplicação

```bash
docker stack deploy -c docker-compose-swarm.yml demo
```

#### Deploy da stack de observabilidade

```bash
cd observability-stack
docker stack deploy -c docker-compose-observability.yml obs
```

Acesse:
- Prometheus: `http://<ip-manager>:9090`
- Grafana: `http://<ip-manager>:3000` (admin/admin)

## Estrutura do Projeto

```
avaliacao-pizzarias/
├── api/
│   ├── Dockerfile
│   ├── main.py                        # API FastAPI com rotas REST
│   └── requirements.txt
├── db/
│   ├── Dockerfile
│   ├── init.sql                       # Script de criação de tabelas e dados iniciais
│   └── password.txt                   # Senha do banco (Docker Secret)
├── docs/
│   └── orquestracao-containers.md     # Documentação detalhada da orquestração
├── frontend/
│   ├── Dockerfile
│   ├── app.py                         # Interface Streamlit
│   └── requirements.txt
├── infra/
│   ├── data.tf                        # Data sources (VPC, AMI)
│   ├── nodes.tf                       # Instâncias EC2 (manager e workers)
│   ├── provider.tf                    # Configuração do provider AWS
│   ├── sg.tf                          # Security Groups
│   ├── variables.tf                   # Variáveis
│   └── templates/
│       └── userdata_docker.sh.tpl     # Script de instalação do Docker
├── nginx/
│   ├── Dockerfile
│   └── nginx.conf                     # Configuração de reverse proxy
├── observability-stack/
│   ├── grafana-datasource.yml         # Provisioning do datasource Prometheus no Grafana
│   ├── prometheus.yml                 # Configuração do Prometheus com Swarm SD
│   └── docker-compose-observability.yml
├── docker-compose.yml                 # Deploy local
├── docker-compose-swarm.yml           # Deploy em Docker Swarm
├── LICENSE
└── README.md
```

## Endpoints da API

| Método | Rota        | Descrição                          |
|--------|-------------|------------------------------------|
| GET    | /avaliacoes | Lista todas as avaliações          |
| POST   | /avaliacoes | Cria uma nova avaliação            |
| GET    | /hostname   | Retorna o hostname do container    |
| GET    | /version    | Retorna a versão da API            |
| GET    | /health     | Healthcheck da API                 |
| GET    | /health/db  | Healthcheck da conexão com o banco |

### Exemplo de payload para criar avaliação

```json
{
  "nome_pizzaria": "Pizzaria Exemplo",
  "nota": 4
}
```

## Observabilidade

A stack de observabilidade é composta por:

| Serviço        | Tecnologia  | Porta | Réplicas |
|----------------|-------------|:-----:|:--------:|
| **prometheus** | Prometheus  | 9090  | 1 (manager) |
| **cadvisor**   | cAdvisor    | 8080  | global (1 por nó) |
| **node-exporter** | Node Exporter | —  | global (1 por nó) |
| **grafana**    | Grafana     | 3000  | 1 (manager) |

O Prometheus usa **Docker Swarm Service Discovery** para descobrir automaticamente os nós e serviços do cluster. O cAdvisor coleta métricas de containers e o Node Exporter coleta métricas do host em cada nó. O Grafana já vem configurado com o Prometheus como datasource padrão.

> O Prometheus e o Grafana rodam exclusivamente no nó manager.

## Tecnologias Utilizadas

- **Python 3.12** — linguagem principal
- **FastAPI 0.111** — framework da API REST
- **Uvicorn 0.30** — servidor ASGI
- **Streamlit 1.36** — interface web interativa
- **PostgreSQL 16** — banco de dados relacional
- **Nginx** — reverse proxy e load balancer
- **Docker / Docker Compose** — containerização e orquestração local
- **Docker Swarm** — orquestração em cluster
- **Prometheus** — coleta e armazenamento de métricas
- **cAdvisor** — métricas de containers
- **Node Exporter** — métricas de host
- **Grafana** — visualização de métricas
- **Terraform** — provisionamento de infraestrutura AWS

## Segurança

A senha do banco de dados é gerenciada via **Docker Secrets** (arquivo `db/password.txt`), evitando expor credenciais em variáveis de ambiente diretamente nos arquivos de compose.

## Licença

Este projeto está licenciado sob a [Apache License 2.0](LICENSE).
