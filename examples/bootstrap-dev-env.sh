#!/bin/bash
# Bootstrap configuration-vault
SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )
K=${KUBECTL}
kind create cluster --name uxp
# up uxp install --set "args={--debug, --enable-realtime-compositions}"
up uxp install \
  --set "resourcesCrossplane.limits.cpu=3000m" \
  --set "resourcesCrossplane.limits.memory=3Gi" \
  --set "resourcesCrossplane.requests.cpu=3000m" \
  --set "resourcesCrossplane.requests.memory=3Gi"
${KUBECTL} -n upbound-system wait --timeout=5m --for=condition=Available deployment --all

${KUBECTL} apply -f ${SCRIPT_DIR}/../examples/function-manifests
${KUBECTL} wait function.pkg --all --timeout 5m --for condition=Healthy
${KUBECTL} apply -f ${SCRIPT_DIR}/../examples/provider-manifests
${KUBECTL} wait provider.pkg --all --timeout 5m --for condition=Healthy
${KUBECTL} apply -f ${SCRIPT_DIR}/../examples/provider-kubernetes-config.yaml

SA=$(${KUBECTL} -n upbound-system get sa -o name|grep provider-kubernetes|\
   sed -e "s|serviceaccount\/|upbound-system:|g")
${KUBECTL} create clusterrolebinding provider-kubernetes-admin-binding \
    --clusterrole cluster-admin --serviceaccount="${SA}"
SA=$(${KUBECTL} -n upbound-system get sa -o name|grep provider-helm|\
   sed -e "s|serviceaccount\/|upbound-system:|g")
${KUBECTL} create clusterrolebinding provider-helm-admin-binding \
    --clusterrole cluster-admin --serviceaccount="${SA}"

find ${SCRIPT_DIR}/../apis -name "definition.yaml"|\
    while read y; do ${KUBECTL} apply -f $y; done
find ${SCRIPT_DIR}/../apis -name "composition.yaml"|\
    while read y; do ${KUBECTL} apply -f $y; done
${KUBECTL} apply -f ${SCRIPT_DIR}/../examples/vault.yaml

echo "waiting for managed resource readiness. This takes several minutes"
${KUBECTL} wait vault.sec.upbound.io configuration-vault --timeout 25m \
    --for condition="Ready"
# Be sure that resources are really ready
${KUBECTL} wait vault.sec.upbound.io configuration-vault --timeout 25m \
    --for condition="Ready"
${KUBECTL} -n vault wait --timeout=25m --for=condition=Available deployment --all

crossplane beta trace vault.sec.upbound.io configuration-vault
${KUBECTL} -n vault port-forward vault-0 8200 2>&1 >/dev/null &
sleep 10
${SCRIPT_DIR}/../test/verify.sh 2>/dev/null

echo "export VAULT_ADDR=http://127.0.0.1:8200 to be able to use the vault cli"
