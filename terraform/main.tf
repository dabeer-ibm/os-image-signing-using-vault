# =============================================================================
# Lookup: AMI ID published by HCP Packer on the named channel
# =============================================================================
data "hcp_packer_artifact" "ubuntu" {
  bucket_name  = var.hcp_packer_bucket
  channel_name = var.hcp_packer_channel
  platform     = "aws"
  region       = var.aws_region
}

# =============================================================================
# Lookup: SSH public key from Vault KV v2
# =============================================================================
data "vault_kv_secret_v2" "ssh" {
  mount = "kv"
  name  = "demo/ssh"
}

# =============================================================================
# Lookup: Vault Transit signature for this AMI
#         (written by packer/sign-ami.sh after `packer build`)
# =============================================================================
data "vault_kv_secret_v2" "ami_signature" {
  mount = "kv"
  name  = "demo/ami-signatures/${data.hcp_packer_artifact.ubuntu.external_identifier}"
}

# =============================================================================
# Verify: POST to transit/verify/<key> and check `data.valid == true`.
# We use the http provider because the vault provider has no transit-verify
# data source. The signed payload is "<region>:<ami-id>" — same construction
# used by sign-ami.sh.
# =============================================================================
locals {
  signed_payload = "${var.aws_region}:${data.hcp_packer_artifact.ubuntu.external_identifier}"
}

data "http" "ami_signature_verify" {
  url    = "${var.vault_addr}/v1/transit/verify/${var.vault_transit_key}"
  method = "POST"
  request_headers = {
    "X-Vault-Token"     = var.vault_token
    "X-Vault-Namespace" = var.vault_namespace
    "Content-Type"      = "application/json"
  }
  request_body = jsonencode({
    input     = base64encode(local.signed_payload)
    signature = data.vault_kv_secret_v2.ami_signature.data["signature"]
  })

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Vault transit/verify call failed (HTTP ${self.status_code}): ${self.response_body}"
    }
  }
}

locals {
  ami_signature_valid = try(
    jsondecode(data.http.ami_signature_verify.response_body).data.valid,
    false,
  )
}

# =============================================================================
# Lookup: default VPC + default security group + first default subnet
#         (we do NOT create any networking resources)
# =============================================================================
data "aws_vpc" "default" {
  default = true
}

data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  location_type = "availability-zone"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.supported.locations
  }
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

# =============================================================================
# Import the SSH public key (from Vault) as an AWS key pair so EC2 can attach it
# =============================================================================
resource "aws_key_pair" "demo" {
  key_name   = "${var.instance_name}-key"
  public_key = data.vault_kv_secret_v2.ssh.data["public_key"]
}

# =============================================================================
# EC2 instance — default VPC, default SG, AMI from HCP Packer, key from Vault
# =============================================================================
resource "aws_instance" "demo" {
  ami           = data.hcp_packer_artifact.ubuntu.external_identifier
  instance_type = var.instance_type
  key_name      = aws_key_pair.demo.key_name

  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [data.aws_security_group.default.id]

  tags = {
    Name        = var.instance_name
    Source      = "hcp-packer"
    ManagedBy   = "terraform"
    Environment = "demo"
  }

  # Refuse to launch unless Vault Transit confirms the AMI signature is valid.
  lifecycle {
    precondition {
      condition     = local.ami_signature_valid
      error_message = "AMI ${data.hcp_packer_artifact.ubuntu.external_identifier} failed Vault transit signature verification (key: ${var.vault_transit_key})."
    }
  }
}
