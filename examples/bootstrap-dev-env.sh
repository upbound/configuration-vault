#!/bin/bash

SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )

kind create cluster --name uxp
up uxp install
kubectl -n upbound-system wait \
    --for=condition=Available deployment --all \
    --timeout=5m

cat <<EOF|kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.1
EOF

cat <<EOF|kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-vault
spec:
  package: xpkg.upbound.io/upbound/provider-vault:v0.3.0
EOF

cat <<EOF|kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.16.0
EOF

kubectl wait provider.pkg --all \
    --for condition=Healthy \
    --timeout 5m

cat <<EOF|kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider-config
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(kubectl -n upbound-system get sa -o name|grep provider-kubernetes | sed -e "s|serviceaccount\/|upbound-system:|g")
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
SA=$(kubectl -n upbound-system get sa -o name|grep provider-helm | sed -e "s|serviceaccount\/|upbound-system:|g")
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

find ${SCRIPT_DIR}/../apis -name "definition.yaml"|\
    while read y; do kubectl apply -f $y; done
find ${SCRIPT_DIR}/../apis -name "composition.yaml"|\
    while read y; do kubectl apply -f $y; done
kubectl apply -f ${SCRIPT_DIR}/../examples/vault.yaml

kubectl wait vault.sec.upbound.io configuration-vault \
    --for condition="Ready" \
    --timeout 5m
kubectl -n vault wait \
   --for=condition=Available deployment --all \
   --timeout=5m

crossplane beta trace vault.sec.upbound.io configuration-vault

kubectl -n vault port-forward vault-0 8200 2>&1 >/dev/null & 
sleep 10
${SCRIPT_DIR}/../test/verify.sh 2>/dev/null

echo "export VAULT_ADDR=http://127.0.0.1:8200"
echo "so that the vault client will be able to connect to the server"
export VAULT_ADDR=http://127.0.0.1:8200
