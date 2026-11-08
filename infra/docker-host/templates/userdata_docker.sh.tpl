#!/bin/bash
set -e

# Instala dependências
apt-get update -y
apt-get install -y ca-certificates curl gnupg

# Adiciona repositório oficial do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "---Configurando permissões para o usuário ubuntu---"
usermod -aG docker ubuntu
sudo newgrp  docker

# Configura métricas do daemon
cat > /etc/docker/daemon.json <<'EOF'
{
  "metrics-addr": "0.0.0.0:9323",
  "experimental": true
}
EOF

systemctl enable docker
systemctl restart docker
