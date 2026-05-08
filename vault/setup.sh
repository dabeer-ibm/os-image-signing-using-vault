#!/usr/bin/env bash
#
# Standalone Vault configuration for the demo.
# Run this once after creating your HCP Vault Dedicated cluster and the AWS
# bootstrap IAM user (see README Step 1).
#
# Required env vars:
#   VAULT_ADDR, VAULT_NAMESPACE, VAULT_TOKEN
#   AWS_REGION
#   AWS_ROOT_ACCESS_KEY  (AccessKeyId of the vault-bootstrap IAM user)
#   AWS_ROOT_SECRET_KEY  (its secret)
#
# What it does (idempotent):
#   • Enables the AWS secrets engine at aws/
#   • Writes aws/config/root with your bootstrap IAM keys
#   • Creates role 'demo-builder' (admin — reusable across future AWS demos)
#   • Enables KV v2 at kv/
#   • Generates an ed25519 SSH keypair and stores it at kv/demo/ssh
#   • Enables Transit at transit/ and creates signing key 'packer-images'
#     (used by Packer to sign AMIs and Terraform to verify them)

set -euo pipefail

: "${VAULT_ADDR:?must be set}"
: "${VAULT_TOKEN:?must be set}"
: "${VAULT_NAMESPACE:=admin}"
: "${AWS_REGION:?must be set (e.g. us-east-1)}"
: "${AWS_ROOT_ACCESS_KEY:?must be set}"
: "${AWS_ROOT_SECRET_KEY:?must be set}"
export VAULT_NAMESPACE

command -v vault      >/dev/null || { echo "vault CLI not in PATH" >&2; exit 1; }
command -v ssh-keygen >/dev/null || { echo "ssh-keygen not in PATH" >&2; exit 1; }

echo "==> Enabling AWS secrets engine at aws/"
vault secrets enable -path=aws aws 2>/dev/null || echo "    already enabled"

echo "==> Writing aws/config/root"
vault write aws/config/root \
  access_key="${AWS_ROOT_ACCESS_KEY}" \
  secret_key="${AWS_ROOT_SECRET_KEY}" \
  region="${AWS_REGION}" >/dev/null

vault write aws/config/lease lease=1h lease_max=2h >/dev/null

echo "==> Writing aws/roles/demo-builder (admin — reusable for future demos)"
vault write aws/roles/demo-builder \
  credential_type=iam_user \
  policy_document=-<<'EOF' >/dev/null
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "*", "Resource": "*" }
  ]
}
EOF

echo "==> Enabling KV v2 at kv/"
vault secrets enable -path=kv -version=2 kv 2>/dev/null || echo "    already enabled"

if vault kv get kv/demo/ssh >/dev/null 2>&1; then
  echo "==> kv/demo/ssh already exists — skipping keypair generation"
else
  echo "==> Generating ed25519 SSH keypair → kv/demo/ssh"
  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "${TMPDIR}"' EXIT
  ssh-keygen -t ed25519 -N "" -C "vault-demo-$(date +%s)" -f "${TMPDIR}/id_demo" >/dev/null
  vault kv put kv/demo/ssh \
    private_key=@"${TMPDIR}/id_demo" \
    public_key=@"${TMPDIR}/id_demo.pub" >/dev/null
fi

echo "==> Enabling Transit at transit/"
vault secrets enable -path=transit transit 2>/dev/null || echo "    already enabled"

echo "==> Creating signing key transit/keys/packer-images (ed25519)"
if vault read transit/keys/packer-images >/dev/null 2>&1; then
  echo "    already exists"
else
  vault write -f transit/keys/packer-images type=ed25519 >/dev/null
fi

cat <<EOF

Vault setup complete.

Verify:
  vault read aws/creds/demo-builder
  vault kv get -field=public_key kv/demo/ssh
  vault read transit/keys/packer-images

Next steps in README.md:
  Step 3 — HCP Packer registry
  Step 4 — packer build
  Step 5 — GitHub repo
  Step 6 — HCP Terraform workspace (VCS-connected)
  Step 7 — git push to deploy
EOF
