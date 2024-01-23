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

echo_info "Running setup.sh"

SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )

kind create cluster --name uxp

echo_info "Checking for kubeconfig"
KUBECONFIG_PATH="${SCRIPT_DIR}/../kubeconfig"
if [ -f "${KUBECONFIG_PATH}" ]; then
    chmod 0600 ${KUBECONFIG_PATH}
fi

echo_info "Checking for upbound-system namespace match"
UPBOUND_SYSTEM_NAMESPACE=$(${KUBECTL} get ns|grep upbound-system|awk '{print $1}') ||true
if [[ "${UPBOUND_SYSTEM_NAMESPACE}" != "upbound-system" ]]; then
    echo "${UPBOUND_SYSTEM_NAMESPACE}"
    up uxp install
fi

${KUBECTL} -n ${UPBOUND_SYSTEM_NAMESPACE} wait \
    --for=condition=Available deployment --all \
    --timeout=5m

cat <<EOF|${KUBECTL} apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.1
EOF

cat <<EOF|${KUBECTL} apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-vault
spec:
  package: xpkg.upbound.io/upbound/provider-vault:v0.3.0
EOF

cat <<EOF|${KUBECTL} apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.16.0
EOF

${KUBECTL} wait provider.pkg --all \
    --for condition=Healthy \
    --timeout 5m

cat <<EOF|${KUBECTL} apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider-config
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(${KUBECTL} -n ${UPBOUND_SYSTEM_NAMESPACE} get sa -o name|grep provider-kubernetes | sed -e "s|serviceaccount\/|${UPBOUND_SYSTEM_NAMESPACE}:|g")
${KUBECTL} create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
SA=$(${KUBECTL} -n ${UPBOUND_SYSTEM_NAMESPACE} get sa -o name|grep provider-helm | sed -e "s|serviceaccount\/|${UPBOUND_SYSTEM_NAMESPACE}:|g")
${KUBECTL} create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

find ${SCRIPT_DIR}/../apis -name "definition.yaml"|\
    while read y; do ${KUBECTL} apply -f $y; done
find ${SCRIPT_DIR}/../apis -name "composition.yaml"|\
    while read y; do ${KUBECTL} apply -f $y; done
${KUBECTL} apply -f ${SCRIPT_DIR}/../examples/vault.yaml

${KUBECTL} wait vault.sec.upbound.io configuration-vault \
    --for condition="Ready" \
    --timeout 5m
${KUBECTL} -n vault wait \
   --for=condition=Available deployment --all \
   --timeout=5m

crossplane beta trace vault.sec.upbound.io configuration-vault

${KUBECTL} -n vault port-forward vault-0 8200 2>&1 >/dev/null &
sleep 10
${SCRIPT_DIR}/../test/verify.sh 2>/dev/null

echo "export VAULT_ADDR=http://127.0.0.1:8200"
echo "so that the vault client will be able to connect to the server"
export VAULT_ADDR=http://127.0.0.1:8200
