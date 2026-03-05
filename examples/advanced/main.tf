# -----------------------------------------------------------------------------
# Advanced Example - Production-Ready k3s Cluster on AWS
# -----------------------------------------------------------------------------
#
# This example creates a highly available k3s cluster with:
# - 3 control-plane servers (HA with etcd quorum)
# - 3 worker agents
# - Custom VPC CIDR and subnets
# - Restricted security group rules
# - Specific k3s version
# - All optional tools installed
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

  cluster_name = "production-k3s"
  ssh_key_name = var.ssh_key_name

  # High availability setup
  server_count            = 3
  server_instance_type    = "t3.large"
  server_root_volume_size = 100

  agent_count            = 3
  agent_instance_type    = "t3.xlarge"
  agent_root_volume_size = 200

  # Custom networking
  vpc_cidr            = "10.50.0.0/16"
  public_subnet_cidrs = ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24"]

  # Restrict access to specific CIDRs
  ssh_allowed_cidrs      = ["10.0.0.0/8", "192.168.1.0/24"]
  k3s_api_allowed_cidrs  = ["10.0.0.0/8", "192.168.1.0/24"]
  nodeport_allowed_cidrs = ["0.0.0.0/0"]

  # k3s configuration
  k3s_version           = "v1.29.0+k3s1"
  flannel_backend       = "vxlan"
  k3s_server_extra_args = "--disable-cloud-controller"
  k3s_agent_extra_args  = ""

  # Install all tools
  install_helm  = true
  install_k9s   = true
  install_stern = true

  # Custom security group rules
  extra_security_group_rules = [
    {
      description = "HTTPS ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      type        = "ingress"
    },
    {
      description = "HTTP ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      type        = "ingress"
    }
  ]

  extra_tags = {
    Environment = "production"
    Project     = "k3s-platform"
    Team        = "platform-engineering"
    CostCenter  = "infrastructure"
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

output "server_ips" {
  description = "Public IPs of all servers"
  value       = module.k3s.server_public_ips
}

output "agent_ips" {
  description = "Public IPs of all agents"
  value       = module.k3s.agent_public_ips
}

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

output "vpc_id" {
  description = "VPC ID"
  value       = module.k3s.vpc_id
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.k3s.security_group_id
}
