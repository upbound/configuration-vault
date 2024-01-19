#!/bin/sh

export VAULT_ADDR="http://127.0.0.1:8200"

vault policy list
vault secrets list
vault list transit/keys
unset VAULT_TOKEN
echo "enter password changeme at the prompt"
vault login -method=userpass username=student
vault write transit/encrypt/payment \
     plaintext=$(base64 <<< "1111-2222-3333-4444")
