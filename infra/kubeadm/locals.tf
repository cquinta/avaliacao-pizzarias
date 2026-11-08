locals {
  common_init = <<-EOF
    set -euxo pipefail

    # Desativa swap
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    # Modulos de kernel
    cat <<MODULES > /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MODULES

    modprobe overlay
    modprobe br_netfilter

    # Parametros sysctl de rede para CNI
    cat <<SYSCTL > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    SYSCTL

    sysctl --system

    # Instala dependencias e containerd
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg netcat-openbsd containerd conntrack

    mkdir -p /etc/containerd
    containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    # Instala kubeadm, kubelet e kubectl (v1.31)
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
  EOF
}