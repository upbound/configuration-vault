# Tutorial

Adapt https://developer.hashicorp.com/vault/tutorials/operations/codify-mgmt-vault-terraform#examine-the-terraform-files

## Create Crossplane Management Cluster

kind create cluster --name uxp
Note: install up if not present
up uxp install


export VAULT_POD_IP=$(kubectl -n vault get pod vault-0 -o yaml|g podIP:|awk '{print $2}')
export VAULT_TOKEN="root"
export VAULT_ADDR="$VAULT_POD_IP:8200"

kubectl create namespace vault
helm install vault hashicorp/vault -n vault --set "server.dev.enabled=true" --set "server.dev.devRootToken=root"

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
