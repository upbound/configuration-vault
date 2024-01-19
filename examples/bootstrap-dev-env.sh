#!/bin/bash

SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )

kind create cluster --name uxp
up uxp install
kubectl -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

kubectl create namespace vault
helm install vault hashicorp/vault -n vault --set "server.dev.enabled=true" --set "server.dev.devRootToken=root"
kubectl -n vault wait --for=condition=Available deployment --all --timeout=5m

VAULT_POD_IP=""
while [[ "${VAULT_POD_IP}" == "" ]]; do
	export VAULT_POD_IP=$(kubectl -n vault get pod vault-0 -o yaml|grep podIP:|awk '{print $2}')
	sleep 5
done

export VAULT_TOKEN="root"
export VAULT_ADDR="$VAULT_POD_IP:8200"

cat <<EOF|kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-vault
spec:
  package: xpkg.upbound.io/upbound/provider-vault:v0.3.0
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: vault-creds
  namespace: vault
type: Opaque
stringData:
  credentials: |
    {
      "token_name": "vault-creds-test-token",
      "token": "$VAULT_TOKEN"
    }
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: student-creds
  namespace: vault
type: Opaque
stringData:
  credentials: |
    {
      "policies": ["admins", "eaas-client"],
      "password": "changeme"
    }
EOF

kubectl wait provider.pkg --all --for condition=Healthy --timeout 5m
cat <<EOF | kubectl apply -f -
apiVersion: vault.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: vault-provider-config
spec:
  address: http://$VAULT_ADDR
  add_address_to_env: false
  headers: {name: test, value: "e2e"}
  max_lease_ttl_seconds: 300
  max_retries: 10
  max_retries_ccc: 10
  namespace: vault
  skip_child_token: true
  skip_get_vault_version: true
  skip_tls_verify: true
  tls_server_name: ""
  vault_version_override: "1.15.2"
  credentials:
    source: Secret
    secretRef:
      name: vault-creds
      namespace: vault
      key: credentials
EOF

find ${SCRIPT_DIR}/../apis/vault -name "definition.yaml"|\
    while read y; do kubectl apply -f $y; done

find ${SCRIPT_DIR}/../apis/vault -name "composition.yaml"|\
    while read y; do kubectl apply -f $y; done

kubectl apply -f ${SCRIPT_DIR}/../examples/vault.yaml
kubectl wait vault.sec.upbound.io configuration-vault --for condition="Ready"
crossplane beta trace vault.sec.upbound.io configuration-vault

kubectl -n vault port-forward vault-0 8200 2>&1 >/dev/null &
${SCRIPT_DIR}/../test/verify.sh 2>/dev/null
