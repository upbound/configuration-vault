#!/bin/bash
# Uptest setup
SCRIPT_DIR=$( cd -- $( dirname -- "${BASH_SOURCE[0]}" ) &> /dev/null && pwd )
${KUBECTL} wait configuration.pkg configuration-vault --for=condition=Healthy --timeout 5m
${KUBECTL} wait configuration.pkg configuration-vault --for=condition=Installed --timeout 5m
${KUBECTL} wait configurationrevisions.pkg --all --for=condition=Healthy --timeout 5m
${KUBECTL} wait xrd --all --for condition=Established

${KUBECTL} -n upbound-system wait --timeout=5m --for=condition=Available deployment --all

${KUBECTL} wait function.pkg --all --timeout 5m --for condition=Healthy
${KUBECTL} wait provider.pkg --all --timeout 5m --for condition=Healthy
${KUBECTL} apply -f ${SCRIPT_DIR}/provider/provider-configs.yaml

SA=$(${KUBECTL} -n upbound-system get sa -o name|grep provider-kubernetes|\
   sed -e "s|serviceaccount\/|upbound-system:|g")
${KUBECTL} create clusterrolebinding provider-kubernetes-admin-binding \
    --clusterrole cluster-admin --serviceaccount="${SA}" || true
SA=$(${KUBECTL} -n upbound-system get sa -o name|grep provider-helm|\
   sed -e "s|serviceaccount\/|upbound-system:|g")
${KUBECTL} create clusterrolebinding provider-helm-admin-binding \
    --clusterrole cluster-admin --serviceaccount="${SA}" || true
