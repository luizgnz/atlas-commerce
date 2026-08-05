# Define the minimum Terraform CLI version required by this root module.
terraform {
  required_version = ">= 1.10.0"

  # Declare every provider used across the flattened 01-aws product stack.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Used to auto-detect the operator's public IP for the EKS endpoint
    # allowlist (see eks_cluster_endpoint_public_access_cidrs in 00-locals.tf).
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }

    # Used to read the EKS OIDC issuer TLS certificate for IRSA (03-eks.tf).
    tls = {
      source = "hashicorp/tls"
    }
  }
}
