variable "aws_region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instância EC2 (mínimo 2 vCPUs para o master)"
  type        = string
  default     = "t3.medium"
}

variable "k8s_token" {
  description = "Token fixo de bootstrap do kubeadm ([a-z0-9]{6}.[a-z0-9]{16})"
  type        = string

}

variable "cidr_block" {

  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.1.0.0/16"
}

