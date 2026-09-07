locals {
  worker_names  = ["swarm-worker01", "swarm-worker02"]
  manager_names = ["swarm-manager"]

}

resource "aws_instance" "manager" {
  for_each      = toset([for no in local.manager_names : tostring(no)])
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnets.work.ids[0]
  tags = {
    Name = each.value
  }
  vpc_security_group_ids = [aws_security_group.swarm_sg.id]
  user_data = templatefile("${path.module}/templates/userdata_docker.sh.tpl", {
    
  })
}

resource "aws_instance" "worker" {
  for_each      = toset([for no in local.worker_names : tostring(no)])
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnets.work.ids[0]
  tags = {
    Name = each.value
  }
  user_data = templatefile("${path.module}/templates/userdata_docker.sh.tpl", {
    
  })
  vpc_security_group_ids = [aws_security_group.swarm_sg.id]
}