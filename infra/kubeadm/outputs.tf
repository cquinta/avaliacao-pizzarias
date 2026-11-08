output "master_public_ip" {
  description = "IP Publico do no Master"
  value       = aws_instance.k8s_master.public_ip
}

output "workers_public_ips" {
  description = "IPs Publicos dos nos Workers"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "ssh_master_command" {
  description = "Comando para conectar ao Master"
  value       = "ssh ubuntu@${aws_instance.k8s_master.public_ip}"
}