resource "aws_security_group" "k8s_sg" {
  name        = "k8s-lab-sg"
  description = "Regras de rede para o cluster k8s"
  vpc_id      = aws_vpc.k8s_vpc.id

  # Libera tráfego irrestrito entre os nós do cluster (CNI, etcd, kubelet)
  ingress {
    description = "Comunicacao interna total entre os nos"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # SSH liberado externamente
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Server do Kubernetes
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "acesso as aplicacoes via NodePort"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-lab-sg"
  }
}