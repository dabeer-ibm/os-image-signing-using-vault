terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.3"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.95"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}
