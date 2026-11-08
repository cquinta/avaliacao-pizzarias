resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.k8s_public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = "vockey"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_init}

    # Inicializa Control Plane com token estatico persistente (ttl=0)
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    kubeadm init \
      --token "${var.k8s_token}" \
      --token-ttl 0 \
      --pod-network-cidr=10.244.0.0/16 \
      --apiserver-advertise-address="$PRIVATE_IP"

    # Configura kubeconfig para usuario ubuntu e root
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Aplica CNI Flannel
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  EOF

  tags = {
    Name = "k8s-master"
    Role = "control-plane"
  }
}

# --- Instâncias Workers ---

resource "aws_instance" "k8s_workers" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = count.index % 2 == 0 ? aws_subnet.k8s_public_subnet_a.id : aws_subnet.k8s_public_subnet_b.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = "vockey"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_init}

    MASTER_IP="${aws_instance.k8s_master.private_ip}"

    # Aguarda o API Server do master responder na porta 6443 antes do join
    until nc -z -v -w5 "$MASTER_IP" 6443; do
      echo "Aguardando API Server do master em $MASTER_IP:6443..."
      sleep 5
    done

    # Join utilizando o token predefinido ignorando a verificacao da CA
    kubeadm join "$MASTER_IP:6443" \
      --token "${var.k8s_token}" \
      --discovery-token-unsafe-skip-ca-verification
  EOF

  tags = {
    Name = "k8s-worker-${count.index + 1}"
    Role = "worker"
  }

  depends_on = [aws_instance.k8s_master]
}