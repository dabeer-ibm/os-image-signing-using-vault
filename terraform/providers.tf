# -----------------------------------------------------------------------------
# Vault provider — reads VAULT_ADDR / VAULT_TOKEN / VAULT_NAMESPACE from env.
# -----------------------------------------------------------------------------
provider "vault" {}

# -----------------------------------------------------------------------------
# Pull dynamic AWS credentials from Vault. The lease lasts the apply lifecycle;
# Terraform automatically revokes the IAM user when the resource is destroyed.
# -----------------------------------------------------------------------------
data "vault_aws_access_credentials" "demo" {
  backend = "aws"
  role    = var.vault_aws_role
  type    = "creds"
}

# -----------------------------------------------------------------------------
# AWS provider — credentials come from Vault, NOT from disk / env.
# -----------------------------------------------------------------------------
provider "aws" {
  region     = var.aws_region
  access_key = data.vault_aws_access_credentials.demo.access_key
  secret_key = data.vault_aws_access_credentials.demo.secret_key
  token      = data.vault_aws_access_credentials.demo.security_token
}

# -----------------------------------------------------------------------------
# HCP provider — uses HCP_CLIENT_ID / HCP_CLIENT_SECRET from env.
# -----------------------------------------------------------------------------
provider "hcp" {}
