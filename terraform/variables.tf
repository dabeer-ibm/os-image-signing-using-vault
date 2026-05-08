variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_name" {
  type    = string
  default = "demo-vault-packer-tf"
}

variable "vault_aws_role" {
  description = "Vault AWS secrets engine role that mints dynamic IAM creds"
  type        = string
  default     = "demo-builder"
}

variable "vault_ssh_kv_path" {
  description = "KV v2 path holding the demo SSH keypair"
  type        = string
  default     = "kv/data/demo/ssh"
}

variable "hcp_packer_bucket" {
  type    = string
  default = "demo-ubuntu-base"
}

variable "hcp_packer_channel" {
  type    = string
  default = "production"
}

# -----------------------------------------------------------------------------
# Vault connection — used by the http data source that calls transit/verify.
# The vault provider itself reads VAULT_ADDR/TOKEN/NAMESPACE from env, but the
# http POST needs them as explicit values, so we duplicate as TF variables.
# -----------------------------------------------------------------------------
variable "vault_addr" {
  type        = string
  description = "VAULT_ADDR (e.g. https://<cluster>.vault.hashicorp.cloud:8200)"
}

variable "vault_namespace" {
  type    = string
  default = "admin"
}

variable "vault_token" {
  type        = string
  description = "Vault token with update on transit/verify/packer-images"
  sensitive   = true
}

variable "vault_transit_key" {
  type        = string
  description = "Transit key used to sign/verify AMIs"
  default     = "packer-images"
}
