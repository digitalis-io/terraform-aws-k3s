# -----------------------------------------------------------------------------
# Worker Agent Nodes
# -----------------------------------------------------------------------------

resource "aws_instance" "agent" {
  count = var.agent_count

  ami                    = local.ami_id
  instance_type          = var.agent_instance_type
  key_name               = var.ssh_key_name
  subnet_id              = local.public_subnet_ids[count.index % local.num_azs]
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  private_ip             = local.agent_private_ips[count.index]

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.agent_root_volume_size
    volume_type           = var.agent_root_volume_type
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${var.cluster_name}-agent-${count.index + 1}-root"
    })
  }

  user_data = templatefile("${path.module}/templates/agent.yaml.tftpl", {
    cluster_name      = var.cluster_name
    k3s_token         = random_password.k3s_token.result
    k3s_version       = var.k3s_version
    k3s_agent_args    = var.k3s_agent_extra_args
    k3s_url           = "https://${local.primary_server_private_ip}:6443"
    install_k9s       = var.install_k9s
    install_stern     = var.install_stern
    node_name         = "${var.cluster_name}-agent-${count.index + 1}"
    node_labels       = "node.kubernetes.io/role=worker"
  })

  tags = merge(local.common_tags, {
    Name                   = "${var.cluster_name}-agent-${count.index + 1}"
    "k3s-role"             = "agent"
    "k3s-agent-index"      = count.index
  })

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
    ]
  }

  depends_on = [
    aws_instance.server,
  ]
}
