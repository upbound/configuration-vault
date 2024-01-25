# configuration-vault
Automate the management of Vault using Crossplane.

## Personas

The scenario described in this reference configuration introduces the following personas:
- admin is the organization-level administrator
- student is a user allowed to write data to a path in vault

## Scope

A manual system administration can become a challenge as the scale of
infrastructure increases. Often, an organization must manage multiple
Vault environments (development, testing, staging, production, etc.).
Keeping up with the increasing management demand soon becomes a
challenge without some sort of automation.

## Solution

Crossplane enables to automate the Vault configuration tasks such as the
creation of policies. Automation through codification allows operators
to increase their productivity, move quicker, promote repeatable processes,
and reduce human error.

This tutorial demonstrates techniques for creating Vault policies and configurations.

## Prerequisites

- A computer with a cloned copy of this git repository.
- The Upbound CLI
```
curl -sL https://cli.upbound.io | sh
```
- [kubectl and kind](https://kubernetes.io/docs/tasks/tools/)

## Scenario

Vault administrators must manage multiple Vault environments.
The test servers get destroyed at the end of each test cycle
and a new set of servers must be provisioned for the next test cycle.
To automate the Vault server configuration, we are going to use
Crossplane to provision the following Vault resources.

|Type         |Name       |Description
|------------:|----------:|---------------------------------
| ACL Policy  | admin     | Sets policies for the admin team
| ACL Policy  | client    | Sets policies for clients to encrypt/decrypt data through transit secrets engine
| auth method | userpass  | Enable and create a user, "student" with admins and fpe-client policies
| secrets engine | transit | Enable transit secrets engine at transit
| encryption key | payment | Encryption key to encrypt/decrypt data

The following steps are demonstrated:
1. Examine Crossplane Compositions
2. Run the Vault installation and configuration
3. Verify the configuration
4. Clean up

## Examine Crossplane Compositions

1. Clone or download the demo assets from the upbound/configuration-vault
Github repository to perform the steps described in this tutorial.
```
git clone git@github.com:upbound/configuration-vault.git
```

2. Change the working directory to `configuration-vault`.
```
cd configuration-vault
```
The directory contains the Crossplane compositions to setup and configure
Vault.
```
tree
```
<code>
.
├── LICENSE
├── Makefile
├── README.md
├── _output
│   └── xpkg
│       ├── cache
│       │   ├── configuration-vault-v0.0.0-11.g55cf092.gz
│       └── linux_arm64
│           ├── configuration-vault-v0.0.0-11.g55cf092.xpkg
├── apis
│   └── vault
│       ├── README.md
│       ├── auth
│       │   ├── composition.yaml
│       │   └── definition.yaml
│       ├── composition.yaml
│       ├── definition.yaml
│       ├── install
│       │   ├── composition.yaml
│       │   └── definition.yaml
│       ├── policies
│       │   ├── composition.yaml
│       │   └── definition.yaml
│       ├── secrets
│       │   ├── composition.yaml
│       │   └── definition.yaml
│       └── user
│           ├── composition.yaml
│           └── definition.yaml
├── build
├── crossplane.yaml
├── docs
├── examples
│   ├── README.md
│   ├── auth.yaml
│   ├── bootstrap-dev-env.sh
│   ├── function-manifests
│   │   └── function-patch-and-transform.yaml
│   ├── policy.yaml
│   ├── provider-kubernetes-config.yaml
│   ├── provider-manifests
│   │   ├── provider-helm.yaml
│   │   ├── provider-kubernetes.yaml
│   │   └── provider-vault.yaml
│   ├── secrets.yaml
│   ├── vault.yaml
│   ├── vaultinstall.yaml
│   └── vaultuser.yaml
└── test
    ├── setup.sh
    └── verify.sh
</code>

The Crossplane compositons are located in the `apis` directory.
Crossplane compositions can be packaged up with information about
the package dependencies that are specified in `crossplane.yaml`.
Please take a look at the
[Crossplane documentation](https://docs.crossplane.io/)
for concepts and a knowledge base if you are not yet familiar.

3. Open the `apis/vault/composition.yaml` and examine its content.
You will notice that the composition implements an xvaults.sec.upbound.io
API. It is layered and this file contains the top layer
creating the following composite resources:
- XAuth
- XPolicy
- XSecret
- XVaultInstall
- XVaultUser
Each of them composes next level resources within their respective
composition files in the `apis/vault` subdirectories.
<code>
---
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  creationTimestamp: "2024-01-25T00:33:27Z"
  name: xvaults.sec.upbound.io
spec:
  compositeTypeRef:
    apiVersion: sec.upbound.io/v1alpha1
    kind: XVault
  mode: Pipeline
  pipeline:
    - functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - base:
              apiVersion: sec.upbound.io/v1alpha1
              kind: XVaultInstall
            name: xVaultInstall
            patches:
              - fromFieldPath: spec.parameters.id
                toFieldPath: spec.parameters.id
                transforms:
                  - string:
                      fmt: '%s-install'
                      type: Format
                    type: string
                type: FromCompositeFieldPath
              - fromFieldPath: status.xVaultInstall
                policy:
                  fromFieldPath: Required
                toFieldPath: status.vaultXVaultInstall
                type: ToCompositeFieldPath
          - base:
              apiVersion: sec.upbound.io/v1alpha1
              kind: XAuth
            name: xVaultAuth
            patches:
              - fromFieldPath: spec.parameters.id
                toFieldPath: spec.parameters.id
                transforms:
                  - string:
                      fmt: '%s-auth'
                      type: Format
                    type: string
                type: FromCompositeFieldPath
              - fromFieldPath: spec.parameters.dataJsonSecretRef
                toFieldPath: spec.parameters.dataJsonSecretRef
                type: FromCompositeFieldPath
              - fromFieldPath: spec.parameters.user
                toFieldPath: spec.parameters.user
                type: FromCompositeFieldPath
              - fromFieldPath: status.vaultXVaultInstall.state
                policy:
                  fromFieldPath: Required
                toFieldPath: spec.parameters.vaultDeployedState
                type: FromCompositeFieldPath
          - base:
              apiVersion: sec.upbound.io/v1alpha1
              kind: XSecret
              spec:
                parameters:
                  providerConfigName: vault-provider-config
            name: xVaultSecrets
            patches:
              - fromFieldPath: spec.parameters.id
                toFieldPath: spec.parameters.id
                type: FromCompositeFieldPath
              - fromFieldPath: spec.parameters.transitKeyName
                toFieldPath: spec.parameters.transitKeyName
                type: FromCompositeFieldPath
              - fromFieldPath: status.vaultXVaultInstall.state
                policy:
                  fromFieldPath: Required
                toFieldPath: spec.parameters.vaultDeployedState
                type: FromCompositeFieldPath
          - base:
              apiVersion: sec.upbound.io/v1alpha1
              kind: XPolicy
              spec:
                parameters:
                  providerConfigName: vault-provider-config
            name: xVaultPolicies
            patches:
              - fromFieldPath: spec.parameters.id
                toFieldPath: spec.parameters.id
                type: FromCompositeFieldPath
              - fromFieldPath: status.vaultXVaultInstall.state
                policy:
                  fromFieldPath: Required
                toFieldPath: spec.parameters.vaultDeployedState
                type: FromCompositeFieldPath
          - base:
              apiVersion: sec.upbound.io/v1alpha1
              kind: XVaultUser
              spec:
                parameters:
                  id: configuration-vault-user
            name: xVaultUser
      step: patch-and-transform
</code>

4. Open the `apis/vault/definition.yaml`. It contains the API definition
specifying the parameters that the implementation in the composition can use.
Individual parameters may be required or optional. The API or also known
as composite resource definition uses the
[openAPIV3Schema](https://swagger.io/specification/).
API definitions can contain status fields that may be populated with
information from the created resources by the composition(s) that
implement the API.
<code>
---
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xvaults.sec.upbound.io
spec:
  group: sec.upbound.io
  names:
    kind: XVault
    plural: xvaults
  claimNames:
    kind: Vault
    plural: vaults
  connectionSecretKeys:
    - kubeconfig
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                parameters:
                  type: object
                  description: >-
                    Vault configuration parameters.
                  properties:
                    id:
                      type: string
                      description: >-
                        ID of this Vault that other objects will
                        use to refer to it.
                    dataJsonSecretRef:
                      type: object
                      description: >-
                        JSON-encoded object that will be
                        written to the given path as the
                        secret data.
                      properties:
                        key:
                          type: string
                          description: >-
                            The key to select.
                        name:
                          type: string
                          description: >-
                            Name of the secret.
                        namespace:
                          type: string
                          description: >-
                            Namespace of the secret.
                    transitKeyName:
                      type: string
                      description: >-
                        Transit key name, e.g. "payment".
                    user:
                      type: string
                      description: >-
                        User for which to write the data,
                        e.g. student. The path where the
                        where the data is written will be
                        auth/userpass/users/<user>.
                    deletionPolicy:
                      description: >-
                        When the Composition is deleted, delete the
                        AWS resources. Defaults to Delete.
                      enum:
                        - Delete
                        - Orphan
                      type: string
                      default: Delete
                    providerConfigName:
                      description: >-
                        Crossplane ProviderConfig to use for
                        provisioning this resource.
                      type: string
                      default: vault-provider-config
                  required:
                    - id
                    - dataJsonSecretRef
                    - transitKeyName
                    - user
              required:
                - parameters
            status:
              type: object
              properties:
                vaultXAuth:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                vaultXVaultInstall:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                vaultXPolicy:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                vaultXSecret:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
                vaultXVaultUser:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
</code>

5. Examine the next level of APIs and their implementation by opening
the following files:
- XAuth composition: `apis/vault/auth/composition.yaml`
- XAuth definition: `apis/vault/auth/definition.yaml`
- XPolicy composition: `apis/vault/policy/composition.yaml`
- XPolicy definition: `apis/vault/policy/definition.yaml`
- XSecret composition: `apis/vault/secrets/composition.yaml`
- XSecret definition: `apis/vault/secrets/definition.yaml`
- XVaultInstall composition: `apis/vault/install/composition.yaml`
- XVaultInstall definition: `apis/vault/install/definition.yaml`
- XVaultUser composition: `apis/vault/user/composition.yaml`
- XVaultUser definition: `apis/vault/user/definition.yaml`

## Run the Vault installation and configuration
Use either one of the following options to install and configure Vault.
1. `make bootstrap` to create all the resources and validate the configuration.
2. `make e2e` to create all the resources and run automated
[KUTTL](https://kuttl.dev/) tests and then validating the configuration.

Resources can be seen using
`crossplane beta render vault.sec.upbound.io configuration-vault`.
This will produce an output like below. Note that there may be various
interim stages leading up to all resources being available.
```
NAME                                                                       SYNCED   READY   STATUS
Vault/configuration-vault (default)                                        True     True    Available
└─ XVault/configuration-vault-6fwtw                                        True     True    Available
   ├─ XAuth/configuration-vault-6fwtw-q2xw9                                True     True    Available
   │  ├─ Backend/configuration-vault-auth-backend-userpass                 True     True    Available
   │  └─ Endpoint/configuration-vault-auth-generic-endpoint                True     True    Available
   ├─ XPolicy/configuration-vault-6fwtw-2mg2k                              True     True    Available
   │  ├─ Policy/configuration-vault-admin-policy                           True     True    Available
   │  └─ Policy/configuration-vault-eaas-client-policy                     True     True    Available
   ├─ XSecret/configuration-vault-6fwtw-4x6k7                              True     True    Available
   │  ├─ SecretBackendKey/configuration-vault-transit-secret-backend-key   True     True    Available
   │  ├─ Mount/configuration-vault-kv-v2-secret-mount                      True     True    Available
   │  └─ Mount/configuration-vault-transit-secret-mount                    True     True    Available
   ├─ XVaultInstall/configuration-vault-6fwtw-vdjq9                        True     True    Available
   │  ├─ Release/configuration-vault-6fwtw-55xbp                           True     True    Available
   │  ├─ Object/configuration-vault-6fwtw-kff7z                            True     True    Available
   │  ├─ Object/configuration-vault-6fwtw-mbqkv                            True     True    Available
   │  ├─ Object/configuration-vault-6fwtw-nbpr6                            True     True    Available
   │  └─ Object/configuration-vault-6fwtw-tn98k                            True     True    Available
   └─ XVaultUser/configuration-vault-6fwtw-s97jk                           True     True    Available
      └─ Object/configuration-vault-6fwtw-mg7hc                            True     True    Available
```

## Verify the configuration
The Vault configuration may be verified using `test/verify.sh`.
It demonstrates how to list configured resources including
policies, secrets, and endpoints, and how the demo student
user can encrypt and decrypt information using a payment
Vault transit key.

## Clean up
Use the following command to delete the local demo cluster.
```
kind delete cluster --name uxp
```
