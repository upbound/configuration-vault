#!/bin/sh

export VAULT_ADDR="http://127.0.0.1:8200"

vault policy list
vault secrets list
vault list transit/keys
unset VAULT_TOKEN
echo "enter password changeme at the prompt"
vault login -method=userpass username=student

echo "\nplaintext: 1111-2222-3333-4444"

PLAINTEXT=$(base64 <<< "1111-2222-3333-4444")
echo "base64 encoded plaintext: ${PLAINTEXT}"

echo "\nencrypt using the payment key"
vault write transit/encrypt/payment \
     plaintext=$(base64 <<< "1111-2222-3333-4444")

CIPHER_TEXT=$(vault write transit/encrypt/payment \
     plaintext=$(base64 <<< "1111-2222-3333-4444")|\
     grep ciphertext|awk '{print $2}')

echo "\ndecrypt using the payment key"
vault write transit/decrypt/payment \
    ciphertext="${CIPHER_TEXT}"

DECRYPTED_CIPHER=$(vault write transit/decrypt/payment \
    ciphertext="${CIPHER_TEXT}"|grep plaintext|awk '{print $2}')

PLAINTEXT=$(base64 --decode <<< "${DECRYPTED_CIPHER}")
echo "\nbase64 decoded plaintext: ${PLAINTEXT}"
