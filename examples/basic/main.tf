# -----------------------------------------------------------------------------
# Basic Example - Minimal k3s Cluster on AWS
# -----------------------------------------------------------------------------
#
# This example creates a minimal k3s cluster with:
# - 1 control-plane server
# - 2 worker agents
# - Default networking (new VPC)
# - Default security settings
#
# Usage:
#   terraform init
#   terraform apply -var="ssh_key_name=my-key"
#
# -----------------------------------------------------------------------------

provider "aws" {
  region = "eu-west-1"
}

module "k3s" {
  source = "../.."

  cluster_name = "my-k3s-cluster"
  ssh_key_name = var.ssh_key_name

  server_count = 1
  agent_count  = 2

  extra_tags = {
    Environment = "development"
    Project     = "k3s-example"
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "primary_server_ip" {
  description = "Public IP of the primary server"
  value       = module.k3s.primary_server_public_ip
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = module.k3s.kubeconfig_command
}

output "ssh_command" {
  description = "SSH command to connect to primary server"
  value       = module.k3s.ssh_command
}
