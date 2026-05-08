packer {
  required_version = ">= 1.10.0"

  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS credentials are taken from the standard env vars
# (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) which Packer's amazon plugin
# reads automatically. Fetch short-lived creds from Vault BEFORE running
# `packer build` — see README Step 4.
#
# We don't use Packer's built-in `vault()` template function because it does
# not honour VAULT_NAMESPACE, which HCP Vault Dedicated requires.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Source: latest official Ubuntu 22.04 LTS AMI from Canonical
# -----------------------------------------------------------------------------
source "amazon-ebs" "ubuntu" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "ubuntu"

  ami_name        = "demo-ubuntu-22-04-${legacy_isotime("20060102-150405")}"
  ami_description = "Hardened Ubuntu 22.04 baked by HCP Packer for the Vault+TF demo"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  tags = {
    Name        = "demo-ubuntu-22-04"
    BuiltBy     = "hcp-packer"
    Environment = "demo"
  }
}

# -----------------------------------------------------------------------------
# Build: minimal hardening + push metadata to HCP Packer registry
# -----------------------------------------------------------------------------
build {
  name    = "demo-ubuntu-base"
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y unattended-upgrades fail2ban",
      "sudo systemctl enable --now fail2ban",
      "echo 'Demo AMI built $(date -u)' | sudo tee /etc/demo-build-info"
    ]
  }

  # Publish artifact metadata to HCP Packer.
  # Requires HCP_CLIENT_ID / HCP_CLIENT_SECRET in environment.
  hcp_packer_registry {
    bucket_name = var.hcp_bucket_name
    description = "Ubuntu 22.04 baseline AMI for the Vault+Terraform demo"

    bucket_labels = {
      "os"      = "ubuntu-22.04"
      "purpose" = "demo"
    }

    build_labels = {
      "build-time" = legacy_isotime("20060102-150405")
    }
  }

  # ---------------------------------------------------------------------------
  # Sign the AMI ID with Vault Transit (key: transit/keys/packer-images) and
  # publish the signature to kv/demo/ami-signatures/<ami-id>. Terraform reads
  # and verifies the signature before launching an instance from this AMI.
  #
  # Requires VAULT_ADDR / VAULT_NAMESPACE / VAULT_TOKEN in env (already set
  # for the dynamic AWS creds step in README Step 4).
  # ---------------------------------------------------------------------------
  post-processors {
    post-processor "manifest" {
      output     = "manifest.json"
      strip_path = true
    }

    post-processor "shell-local" {
      inline = ["./sign-ami.sh manifest.json"]
    }
  }
}
