#!/bin/bash
# Script for generic HashiCorp vault interaction
export VAULT_ADDR="https://vault0.$ENV.dplt.eu:8200"
export VAULT_TOKEN=''

# Delete ALL versions (only first level)
vault kv metadata delete -tls-skip-verify secret/tessie/mysecret
vault kv delete -tls-skip-verify secret/tessie/mysecret

