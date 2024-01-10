#!/bin/bash
# Uptest setup
SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )
${KUBECTL} -n upbound-system wait --timeout=5m --for=condition=Available deployment --all

${KUBECTL} wait function.pkg --all --timeout 5m --for condition=Healthy
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
