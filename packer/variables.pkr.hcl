variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "hcp_bucket_name" {
  type    = string
  default = "demo-ubuntu-base"
}

variable "hcp_bucket_channel" {
  type    = string
  default = "production"
}

variable "vault_addr" {
  type    = string
  default = env("VAULT_ADDR")
}

variable "vault_namespace" {
  type    = string
  default = env("VAULT_NAMESPACE")
}

variable "vault_token" {
  type      = string
  default   = env("VAULT_TOKEN")
  sensitive = true
}
