# -----------------------------------------------------------------------------
# Server Outputs
# -----------------------------------------------------------------------------

output "server_public_ips" {
  description = "Map of server names to public IP addresses"
  value = {
    for instance in aws_instance.server : instance.tags["Name"] => instance.public_ip
  }
}

output "server_private_ips" {
  description = "Map of server names to private IP addresses"
  value = {
    for instance in aws_instance.server : instance.tags["Name"] => instance.private_ip
  }
}

output "server_instance_ids" {
  description = "Map of server names to instance IDs"
  value = {
    for instance in aws_instance.server : instance.tags["Name"] => instance.id
  }
}

# -----------------------------------------------------------------------------
# Agent Outputs
# -----------------------------------------------------------------------------

output "agent_public_ips" {
  description = "Map of agent names to public IP addresses"
  value = {
    for instance in aws_instance.agent : instance.tags["Name"] => instance.public_ip
  }
}

output "agent_private_ips" {
  description = "Map of agent names to private IP addresses"
  value = {
    for instance in aws_instance.agent : instance.tags["Name"] => instance.private_ip
  }
}

output "agent_instance_ids" {
  description = "Map of agent names to instance IDs"
  value = {
    for instance in aws_instance.agent : instance.tags["Name"] => instance.id
  }
}

# -----------------------------------------------------------------------------
# Primary Server
# -----------------------------------------------------------------------------

output "primary_server_public_ip" {
  description = "Public IP of the primary control-plane server"
  value       = var.server_count > 0 ? aws_instance.server[0].public_ip : null
}

output "primary_server_private_ip" {
  description = "Private IP of the primary control-plane server"
  value       = var.server_count > 0 ? aws_instance.server[0].private_ip : null
}

# -----------------------------------------------------------------------------
# Cluster Access
# -----------------------------------------------------------------------------

output "k3s_token" {
  description = "K3s cluster token for joining nodes"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from the primary server"
  value       = var.server_count > 0 ? "ssh -o StrictHostKeyChecking=no ubuntu@${aws_instance.server[0].public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${aws_instance.server[0].public_ip}/g'" : null
}

output "ssh_command" {
  description = "SSH command to connect to the primary server"
  value       = var.server_count > 0 ? "ssh ubuntu@${aws_instance.server[0].public_ip}" : null
}

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = local.public_subnet_ids
}

output "security_group_id" {
  description = "ID of the cluster security group"
  value       = aws_security_group.cluster.id
}

# -----------------------------------------------------------------------------
# AMI Information
# -----------------------------------------------------------------------------

output "ami_id" {
  description = "AMI ID used for the instances"
  value       = local.ami_id
}

output "ami_name" {
  description = "Name of the AMI used"
  value       = data.aws_ami.digitalis_hardened.name
}
