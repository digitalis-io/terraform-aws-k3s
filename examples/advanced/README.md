# Advanced Example

This example demonstrates a production-ready, highly available k3s cluster deployment on AWS.

## What it creates

- 3 control-plane server nodes (HA with etcd quorum)
- 3 worker agent nodes
- Custom VPC with specific CIDR ranges
- Restricted security group rules
- Custom firewall rules for HTTP/HTTPS ingress
- Specific k3s version pinning

## Usage

```bash
# Initialize Terraform
terraform init

# Deploy the cluster
terraform apply -var="ssh_key_name=my-key"

# Or specify a different region
terraform apply -var="ssh_key_name=my-key" -var="region=us-east-1"
```

## Accessing the cluster

```bash
# Get the kubeconfig
$(terraform output -raw kubeconfig_command) > ~/.kube/k3s-config
export KUBECONFIG=~/.kube/k3s-config

# Verify
kubectl get nodes
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region | AWS region to deploy the cluster | `string` | `"eu-west-1"` | no |
| ssh_key_name | Name of the EC2 key pair for SSH access | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| server_ips | Public IPs of all servers |
| agent_ips | Public IPs of all agents |
| primary_server_ip | Public IP of the primary server |
| kubeconfig_command | Command to retrieve kubeconfig |
| ssh_command | SSH command to connect to primary server |
| vpc_id | VPC ID |
| security_group_id | Security group ID |

## Customization

This example showcases several advanced features:

- **High Availability**: 3 control-plane servers for etcd quorum (tolerates 1 failure)
- **Custom Networking**: VPC CIDR `10.50.0.0/16` with custom subnet ranges
- **Restricted Access**: SSH and k3s API limited to internal networks
- **Ingress Rules**: HTTP (80) and HTTPS (443) open for web traffic
- **Version Pinning**: Specific k3s version for reproducible deployments
