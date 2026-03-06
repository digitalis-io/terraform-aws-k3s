# -----------------------------------------------------------------------------
# SSH & Cluster Identity
# -----------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Name of the EC2 key pair to use for SSH access"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "digitalis-k3s"
}

# -----------------------------------------------------------------------------
# Server Pool (Control-Plane)
# -----------------------------------------------------------------------------

variable "server_count" {
  description = "Number of control-plane server nodes (must be odd for etcd quorum)"
  type        = number
  default     = 1

  validation {
    condition     = var.server_count % 2 == 1
    error_message = "Server count must be an odd number for etcd quorum (1, 3, 5, etc.)."
  }
}

variable "server_instance_type" {
  description = "EC2 instance type for server nodes (must match ami_architecture)"
  type        = string
  default     = "t3.medium"
}

variable "server_root_volume_size" {
  description = "Root volume size in GB for server nodes"
  type        = number
  default     = 50
}

variable "server_root_volume_type" {
  description = "Root volume type for server nodes"
  type        = string
  default     = "gp3"
}

# -----------------------------------------------------------------------------
# Agent Pool (Workers)
# -----------------------------------------------------------------------------

variable "agent_count" {
  description = "Number of worker agent nodes"
  type        = number
  default     = 2
}

variable "agent_instance_type" {
  description = "EC2 instance type for agent nodes (must match ami_architecture)"
  type        = string
  default     = "t3.medium"
}

variable "agent_root_volume_size" {
  description = "Root volume size in GB for agent nodes"
  type        = number
  default     = 50
}

variable "agent_root_volume_type" {
  description = "Root volume type for agent nodes"
  type        = string
  default     = "gp3"
}

# -----------------------------------------------------------------------------
# Location & AMI
# -----------------------------------------------------------------------------

variable "availability_zones" {
  description = "List of availability zones to use. If empty, uses the first available in the region."
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "AMI ID to use for instances. If not specified, uses the Digitalis hardened Ubuntu AMI."
  type        = string
  default     = null
}

variable "ami_architecture" {
  description = "Architecture for the default AMI (amd64 or arm64). Must match instance type architecture."
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.ami_architecture)
    error_message = "AMI architecture must be 'amd64' or 'arm64'."
  }
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "create_vpc" {
  description = "Whether to create a new VPC or use an existing one"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of existing VPC to use (required if create_vpc is false)"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.13.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.13.1.0/24", "10.13.2.0/24", "10.13.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ). If empty, nodes use public subnets."
  type        = list(string)
  default     = []
}

variable "existing_subnet_ids" {
  description = "List of existing subnet IDs to use (required if create_vpc is false)"
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "Whether to associate public IP addresses with instances"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Security / Firewall
# -----------------------------------------------------------------------------

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to access SSH (port 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "k3s_api_allowed_cidrs" {
  description = "CIDR blocks allowed to access k3s API (port 6443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_allowed_cidrs" {
  description = "CIDR blocks allowed to access NodePort services (30000-32767)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_security_group_rules" {
  description = "Additional security group rules to add"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    type        = string # ingress or egress
  }))
  default = []
}

# -----------------------------------------------------------------------------
# k3s Options
# -----------------------------------------------------------------------------

variable "k3s_version" {
  description = "k3s version to install (e.g., 'v1.29.0+k3s1'). Empty string installs latest stable."
  type        = string
  default     = ""
}

variable "k3s_server_extra_args" {
  description = "Extra arguments for k3s server installation"
  type        = string
  default     = ""
}

variable "k3s_agent_extra_args" {
  description = "Extra arguments for k3s agent installation"
  type        = string
  default     = ""
}

variable "flannel_backend" {
  description = "Flannel backend to use (vxlan, wireguard-native, host-gw, none)"
  type        = string
  default     = "vxlan"
}

# -----------------------------------------------------------------------------
# Optional Tools
# -----------------------------------------------------------------------------

variable "install_helm" {
  description = "Whether to install Helm on server nodes"
  type        = bool
  default     = true
}

variable "install_k9s" {
  description = "Whether to install k9s on all nodes"
  type        = bool
  default     = true
}

variable "install_stern" {
  description = "Whether to install Stern on all nodes"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags / Labels
# -----------------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
