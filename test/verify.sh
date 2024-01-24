#!/usr/bin/env bash
set -aeuo pipefail

# setting up colors
BLU='\033[0;104m'
YLW='\033[0;33m'
GRN='\033[0;32m'
RED='\033[0;31m'
NOC='\033[0m' # No Color

echo_info(){
    printf "\n${BLU}%s${NOC}\n" "$1"
}
echo_step(){
    printf "\n${BLU}>>>>>>> %s${NOC}\n" "$1"
}
echo_step_completed(){
    printf "${GRN} [✔] %s${NOC}\n" "$1"
}

echo_info "Running verify.sh"

SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

echo_step "log in as admin"
vault login - <<< $VAULT_TOKEN
echo_step_completed "log in as admin"

echo_step "vault policy list"
vault policy list
echo_step_completed "vault policy list"

echo_step "vault secrets list"
vault secrets list
echo_step_completed "vault secrets list"

echo_step "vault list transit/keys"
vault list transit/keys
echo_step_completed "vault list transit/keys"

echo_step "log in as student user, encrypt plain text with transit key, and decrypt"
unset VAULT_TOKEN
echo_step_completed "unset VAULT_TOKEN"
echo "below, use password: changeme"
vault login -method=userpass username=student
echo_step_completed "vault login -method=userpass username=student"

PLAINTEXT="1111-2222-3333-4444"
echo_step_completed "using plaintext: ${PLAINTEXT}"

BASE64_ENCODED_PLAINTEXT=$(base64 <<< "${PLAINTEXT}")
echo_step_completed "base64 encoded plaintext: ${BASE64_ENCODED_PLAINTEXT}"

echo_step "encrypt using the payment key"
vault write transit/encrypt/payment \
    plaintext=${BASE64_ENCODED_PLAINTEXT}
echo_step_completed "encrypt using the payment key"

CIPHER_TEXT=$(vault write transit/encrypt/payment \
    plaintext=${BASE64_ENCODED_PLAINTEXT}|\
     grep ciphertext|awk '{print $2}')

echo_step "decrypt using the payment key"
vault write transit/decrypt/payment \
    ciphertext="${CIPHER_TEXT}"
echo_step_completed "decrypt using the payment key"

DECRYPTED_CIPHER=$(vault write transit/decrypt/payment \
    ciphertext="${CIPHER_TEXT}"|grep plaintext|awk '{print $2}')

PLAINTEXT2=$(base64 --decode <<< "${DECRYPTED_CIPHER}")
echo_step_completed "base64 decoded plaintext: ${PLAINTEXT2}"

if [[ "${PLAINTEXT}" == "${PLAINTEXT2}" ]]; then
	echo_step_completed "Success! Decrypted plaintext matches original"
else
	echo_step_completed "Failure! One or more of the above steps failed"
fi
