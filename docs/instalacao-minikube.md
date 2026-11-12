# Instalação do Minikube

## Pré-requisitos

- Ubuntu (testado em EC2 com AMI Ubuntu)
- Acesso root ou sudo

## Passo a Passo

### 1. Instalar o Docker

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 2. Configurar permissões do Docker

```bash
sudo usermod -aG docker ubuntu
sudo newgrp docker
sudo systemctl enable docker
sudo systemctl start docker
```

### 3. Instalar o kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Verifique a instalação:

```bash
kubectl version --client
```

### 4. Instalar o Minikube

```bash
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
```

Verifique a instalação:

```bash
minikube version
```

### 5. Iniciar o Minikube

```bash
minikube start --driver=docker
```

> **Atenção:** Execute como usuário `ubuntu` (não root) para usar o driver Docker.

### 6. Verificar o cluster

```bash
kubectl get nodes
minikube status
```

## Manutenção

### Limpar imagens e cache do Minikube

Para forçar o pull de imagens atualizadas, limpe o cache do Docker dentro do Minikube:

```bash
minikube ssh -- docker system prune -a --volumes -f
```

Depois reinicie os deployments para puxar as novas imagens:

```bash
kubectl rollout restart deployment/<nome-do-deployment>
```
