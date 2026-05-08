#!/usr/bin/env bash
#
# Sign the AMI ID published by `packer build` using Vault Transit, then store
# the signature in Vault KV so Terraform can verify it before deploy.
#
# Invoked by the `shell-local` post-processor in ami.pkr.hcl.
#
# Required env vars:
#   VAULT_ADDR, VAULT_NAMESPACE, VAULT_TOKEN
#
# Usage:
#   ./sign-ami.sh <manifest.json>

set -euo pipefail

MANIFEST="${1:-manifest.json}"

: "${VAULT_ADDR:?must be set}"
: "${VAULT_TOKEN:?must be set}"
: "${VAULT_NAMESPACE:=admin}"
export VAULT_NAMESPACE

command -v vault >/dev/null || { echo "vault CLI not in PATH" >&2; exit 1; }
command -v jq    >/dev/null || { echo "jq not in PATH" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }

# Packer's manifest post-processor records artifact_id as "<region>:<ami-id>"
# (comma-separated for multi-region builds — we only build in one region).
last_run_uuid=$(jq -r '.last_run_uuid' "$MANIFEST")
artifact_id=$(jq -r --arg u "$last_run_uuid" \
  '.builds[] | select(.packer_run_uuid==$u) | .artifact_id' "$MANIFEST")

region="${artifact_id%%:*}"
ami_id="${artifact_id##*:}"

# Payload binds the AMI ID to its region — verifier reconstructs and re-signs.
payload="${region}:${ami_id}"
b64=$(printf '%s' "$payload" | base64 | tr -d '\n')

echo "==> Signing payload '${payload}' with transit/keys/packer-images"
sig_resp=$(vault write -format=json transit/sign/packer-images input="$b64")
signature=$(echo "$sig_resp" | jq -r .data.signature)
key_version=$(echo "$sig_resp" | jq -r .data.key_version)

echo "==> Storing signature → kv/demo/ami-signatures/${ami_id}"
vault kv put "kv/demo/ami-signatures/${ami_id}" \
  ami_id="$ami_id" \
  region="$region" \
  payload="$payload" \
  signature="$signature" \
  key_version="$key_version" \
  signed_at="$(date -u +%FT%TZ)" >/dev/null

echo "    signature: ${signature}"
echo "    key version: ${key_version}"
