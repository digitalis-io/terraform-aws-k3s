# Basic Example

This example demonstrates a minimal k3s cluster deployment on AWS.

## What it creates

- 1 control-plane server node
- 3 worker agent nodes
- New VPC with public subnets
- Security groups for SSH, k3s API, and NodePort services

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
| primary_server_ip | Public IP of the primary server |
| kubeconfig_command | Command to retrieve kubeconfig |
| ssh_command | SSH command to connect to primary server |
