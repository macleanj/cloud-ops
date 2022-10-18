#!/bin/bash
# Script to tidy (prune and cleanup) all expired certificates
# https://www.vaultproject.io/api-docs/secret/pki#tidy

[ -z "${vault_token}" ] && read -p "Enter vault token: " vault_token
# echo "Vault token: ${vault_token}"

generate_post_data()
{
  cat <<EOF
{
  "tidy_cert_store"   : true,
  "tidy_revoked_certs": true,
  "safety_buffer"     : "1h"
}
EOF
}

curl -X POST \
  https://localhost:8200/v1/pki/tidy \
  -H "content-type: application/json" \
  -H "x-vault-token: ${vault_token}" \
  -d "$(generate_post_data)"
