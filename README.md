# Terraform AWS K3s Module

This Terraform module deploys a production-ready [k3s](https://k3s.io/) Kubernetes cluster on AWS using EC2 instances with the Digitalis hardened Ubuntu AMI.

## Features

- **High Availability**: Support for multi-server control plane with etcd quorum
- **Separate Node Pools**: Independent scaling for control-plane servers and worker agents
- **Private Networking**: VPC with configurable CIDR and public subnets
- **Security Groups**: Fine-grained firewall rules for SSH, k3s API, and NodePort services
- **IAM Integration**: EC2 instances with IAM roles for AWS API access
- **Cloud-init**: Automated k3s installation and configuration at boot
- **Optional Tools**: Helm, k9s, and Stern pre-installed

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        AWS VPC (10.13.0.0/16)                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐      │
│  │  Public Subnet │  │  Public Subnet │  │  Public Subnet │      │
│  │  10.13.1.0/24  │  │  10.13.2.0/24  │  │  10.13.3.0/24  │      │
│  │    (AZ-1)      │  │    (AZ-2)      │  │    (AZ-3)      │      │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘      │
│          │                   │                   │               │
│  ┌───────┴────────┐  ┌───────┴────────┐  ┌───────┴────────┐      │
│  │   Server-1     │  │   Server-2     │  │   Server-3     │      │
│  │   (Control)    │  │   (Control)    │  │   (Control)    │      │
│  │   .10          │  │   .10          │  │   .10          │      │
│  └────────────────┘  └────────────────┘  └────────────────┘      │
│                                                                  │
│  ┌───────┴────────┐  ┌───────┴────────┐  ┌───────┴────────┐      │
│  │   Agent-1      │  │   Agent-2      │  │   Agent-3      │      │
│  │   (Worker)     │  │   (Worker)     │  │   (Worker)     │      │
│  │   .100         │  │   .100         │  │   .100         │      │
│  └────────────────┘  └────────────────┘  └────────────────┘      │
│                                                                  │
│  Security Group: SSH(22), K3s API(6443), NodePort(30000-32767)   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0.0 |
| random | >= 3.5.0 |

## Usage

### Basic Example

```hcl
provider "aws" {
  region = "eu-west-1"
}

module "k3s" {
  source = "path/to/terraform-aws-k3s"

  cluster_name = "my-k3s-cluster"
  ssh_key_name = "my-ec2-keypair"

  server_count = 1
  agent_count  = 2
}

output "kubeconfig_command" {
  value = module.k3s.kubeconfig_command
}
```

### High Availability Example

```hcl
module "k3s" {
  source = "path/to/terraform-aws-k3s"

  cluster_name = "production-k3s"
  ssh_key_name = "my-ec2-keypair"

  # HA control plane (odd number for etcd quorum)
  server_count         = 3
  server_instance_type = "t3.large"

  # Worker pool
  agent_count          = 5
  agent_instance_type  = "t3.xlarge"

  # Restrict access
  ssh_allowed_cidrs     = ["10.0.0.0/8"]
  k3s_api_allowed_cidrs = ["10.0.0.0/8"]

  # Specific k3s version
  k3s_version = "v1.29.0+k3s1"
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| ssh_key_name | Name of the EC2 key pair for SSH access | `string` |

### Cluster Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| cluster_name | Name prefix for all resources | `string` | `"digitalis-k3s"` |
| server_count | Number of control-plane servers (must be odd) | `number` | `1` |
| agent_count | Number of worker agents | `number` | `2` |
| server_instance_type | EC2 instance type for servers | `string` | `"t3.medium"` |
| agent_instance_type | EC2 instance type for agents | `string` | `"t3.medium"` |
| ami_architecture | AMI architecture (amd64 or arm64) | `string` | `"amd64"` |
| server_root_volume_size | Root volume size (GB) for servers | `number` | `50` |
| agent_root_volume_size | Root volume size (GB) for agents | `number` | `50` |

### Networking

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_vpc | Create a new VPC | `bool` | `true` |
| vpc_id | Existing VPC ID (if create_vpc=false) | `string` | `null` |
| vpc_cidr | VPC CIDR block | `string` | `"10.13.0.0/16"` |
| public_subnet_cidrs | Public subnet CIDR blocks | `list(string)` | `["10.13.1.0/24", "10.13.2.0/24", "10.13.3.0/24"]` |
| associate_public_ip | Associate public IPs with instances | `bool` | `true` |

### Security

| Name | Description | Type | Default |
|------|-------------|------|---------|
| ssh_allowed_cidrs | CIDRs allowed for SSH access | `list(string)` | `["0.0.0.0/0"]` |
| k3s_api_allowed_cidrs | CIDRs allowed for k3s API access | `list(string)` | `["0.0.0.0/0"]` |
| nodeport_allowed_cidrs | CIDRs allowed for NodePort services | `list(string)` | `["0.0.0.0/0"]` |

### K3s Options

| Name | Description | Type | Default |
|------|-------------|------|---------|
| k3s_version | K3s version (empty = latest) | `string` | `""` |
| k3s_server_extra_args | Extra k3s server arguments | `string` | `""` |
| k3s_agent_extra_args | Extra k3s agent arguments | `string` | `""` |
| flannel_backend | Flannel backend (vxlan, wireguard-native) | `string` | `"vxlan"` |

### Optional Tools

| Name | Description | Type | Default |
|------|-------------|------|---------|
| install_helm | Install Helm on servers | `bool` | `true` |
| install_k9s | Install k9s on all nodes | `bool` | `true` |
| install_stern | Install Stern on all nodes | `bool` | `true` |

## Outputs

| Name | Description |
|------|-------------|
| server_public_ips | Map of server names to public IPs |
| server_private_ips | Map of server names to private IPs |
| agent_public_ips | Map of agent names to public IPs |
| agent_private_ips | Map of agent names to private IPs |
| primary_server_public_ip | Public IP of the primary server |
| primary_server_private_ip | Private IP of the primary server |
| k3s_token | K3s cluster token (sensitive) |
| kubeconfig_command | Command to retrieve kubeconfig |
| ssh_command | SSH command to connect to primary server |
| vpc_id | VPC ID |
| security_group_id | Security group ID |
| ami_id | AMI ID used for instances |

## Accessing the Cluster

After deployment, retrieve the kubeconfig:

```bash
# Use the output command
$(terraform output -raw kubeconfig_command) > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config

# Verify access
kubectl get nodes
```

Or SSH into the primary server:

```bash
$(terraform output -raw ssh_command)
sudo kubectl get nodes
```

## AMI

This module uses the Digitalis hardened Ubuntu AMI from AWS Marketplace by default:

```hcl
data "aws_ami" "digitalis_hardened" {
  most_recent = true
  owners      = ["aws-marketplace", "679593333241", "436673215683"]

  filter {
    name   = "name"
    values = ["digitalis-hardened*"]
  }
}
```

You can select the architecture using the `ami_architecture` variable (`amd64` or `arm64`). Ensure your instance types match the architecture:
- **amd64** (default): Use `t3`, `m6i`, `c6i`, etc.
- **arm64**: Use `t4g`, `m7g`, `c7g`, `r7g`, etc.

## Security Considerations

1. **SSH Access**: Restrict `ssh_allowed_cidrs` to known IP ranges
2. **K3s API**: Restrict `k3s_api_allowed_cidrs` to internal networks or VPN
3. **Encryption**: Root volumes are encrypted by default
4. **IAM**: Minimal IAM permissions for EC2 instances
5. **Hardened AMI**: Uses Digitalis hardened Ubuntu for improved security

## License

Apache License 2.0
