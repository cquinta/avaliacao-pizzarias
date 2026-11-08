# Infraestrutura Kubernetes com kubeadm na AWS

Provisiona um cluster Kubernetes com 1 nó control-plane e 2 workers em EC2, usando kubeadm para bootstrap e Flannel como CNI.

## Arquitetura

```
VPC (10.1.0.0/16)
├── Subnet pública A (10.1.1.0/24) — us-east-1a
│   ├── k8s-master   (control-plane)
│   └── k8s-worker-1
└── Subnet pública B (10.1.2.0/24) — us-east-1b
    └── k8s-worker-2
```

| Recurso         | Detalhes                        |
|-----------------|---------------------------------|
| AMI             | Ubuntu 24.04 LTS (Canonical)    |
| Instance type   | t3.medium (padrão)              |
| Kubernetes      | v1.31                           |
| CNI             | Flannel (10.244.0.0/16)         |
| Container runtime | containerd                    |

## Portas abertas (Security Group)

| Porta       | Protocolo | Origem    | Uso                        |
|-------------|-----------|-----------|----------------------------|
| 22          | TCP       | 0.0.0.0/0 | SSH                        |
| 6443        | TCP       | 0.0.0.0/0 | Kubernetes API Server      |
| 30000-32767 | TCP       | 0.0.0.0/0 | NodePort                   |
| all         | all       | self      | Comunicação interna do cluster |

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configurado com credenciais válidas (`aws configure`)
- Key pair existente na AWS (padrão: `vockey`)
- Chave privada correspondente ao key pair disponível localmente para acesso SSH às instâncias

## Variáveis

| Variável        | Descrição                                              | Padrão        | Obrigatória |
|-----------------|--------------------------------------------------------|---------------|:-----------:|
| `aws_region`    | Região AWS                                             | `us-east-1`   | não         |
| `instance_type` | Tipo de instância EC2 (mínimo 2 vCPUs para o master)  | `t3.medium`   | não         |
| `cidr_block`    | Bloco CIDR da VPC                                      | `10.1.0.0/16` | não         |
| `k8s_token`     | Token de bootstrap do kubeadm (`[a-z0-9]{6}.[a-z0-9]{16}`) | —        | sim         |

## Como usar

### 1. Configurar variáveis

Crie o arquivo de variáveis a partir do exemplo:

```bash
cp environment/lab/terraform.tfvars.example environment/lab/terraform.tfvars
```

Ou crie manualmente:

```hcl
# environment/lab/terraform.tfvars
aws_region    = "us-east-1"
instance_type = "t3.medium"
k8s_token     = "abcdef.0123456789abcdef"
```

> O token deve seguir o formato `[a-z0-9]{6}.[a-z0-9]{16}`. Gere um com:
> ```bash
> kubeadm token generate
> ```

### 2. Inicializar e aplicar

```bash
terraform init
terraform apply -var-file=environment/lab/terraform.tfvars
```

### 3. Acessar o cluster

```bash
# Acessa o master
ssh -i <chave-privada> ubuntu@<ip-master>

# Verifica os nós
kubectl get nodes
```

Os workers fazem join automático ao master via token. Aguarde ~2 minutos após o `apply` para o cluster estar pronto.

### 4. Destruir

```bash
terraform destroy -var-file=environment/lab/terraform.tfvars
```

## Estrutura dos arquivos

```
infra/kubeadm/
├── environment/
│   └── lab/
│       └── terraform.tfvars      # Variáveis do ambiente (não versionado)
├── data.tf                       # AMI Ubuntu mais recente
├── locals.tf                     # Script comum de inicialização dos nós
├── nodes.tf                      # Instâncias EC2 (master e workers)
├── provider.tf                   # Provider AWS
├── sg.tf                         # Security Group
├── variables.tf                  # Declaração de variáveis
└── vpc.tf                        # VPC, subnets e route tables
```
