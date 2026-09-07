locals {
  swarm_tcp_ports  = [2377, 7946, 9323, 8080, 9090, 80, 443]
  swarm_udp_ports  = [7946, 4789]
  public_tcp_ports = [22, 80, 8080, 9090, 3000]
}

resource "aws_security_group" "swarm_sg" {
  name        = "swarm-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = data.aws_vpc.work.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "tcp" {
  for_each = toset([for p in local.swarm_tcp_ports : tostring(p)])

  security_group_id            = aws_security_group.swarm_sg.id
  referenced_security_group_id = aws_security_group.swarm_sg.id
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "udp" {
  for_each = toset([for p in local.swarm_udp_ports : tostring(p)])

  security_group_id            = aws_security_group.swarm_sg.id
  referenced_security_group_id = aws_security_group.swarm_sg.id
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "public" {
  for_each = toset([for p in local.public_tcp_ports : tostring(p)])

  security_group_id = aws_security_group.swarm_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
}
