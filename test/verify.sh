#!/bin/sh

echo "\n=== Policies ==="
curl -H "X-Vault-Token: root" -X GET "http://127.0.0.1:8200/v1/sys/policies/acl?list=true"|jq .data.keys.[]|tr -d '"'

echo "\n=== Mount Path ==="
curl -H "X-Vault-Token: root" -X GET "http://127.0.0.1:8200/v1/sys/mounts"|jq '.data.[].'|tr -d '"'

echo "\n=== Mount Accessors ==="
curl -H "X-Vault-Token: root" -X GET "http://127.0.0.1:8200/v1/sys/mounts"|jq '.data.[].accessor'|tr -d '"'

echo "\n=== Mount Types ==="
curl -H "X-Vault-Token: root" -X GET "http://127.0.0.1:8200/v1/sys/mounts"|jq '.data.[].type'|tr -d '"'

echo "\n=== Payment Transit Key ==="
curl -H "X-Vault-Token: root" -X GET "http://127.0.0.1:8200/v1/transit/keys?list=true"|jq .data.keys.[]|tr -d '"'
