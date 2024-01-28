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
| auth method | userpass  | Enable and create a user, "student" with admins and eaas-client policies
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

4. Open the `apis/vault/definition.yaml`. It contains the API definition
specifying the parameters that the implementation in the composition can use.
Individual parameters may be required or optional. The API also known
as composite resource definition uses the
[openAPIV3Schema](https://swagger.io/specification/).
API definitions can contain status fields that may be populated with
information from the created resources by the composition(s) that
implement the API.

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
`crossplane beta trace vault.sec.upbound.io configuration-vault`.
This will produce an output like below. Note that there may be various
interim stages leading up to all resources being available.
```
NAME                                                                       SYNCED   READY   STATUS
Vault/configuration-vault (default)                                        True     True    Available
└─ XVault/configuration-vault-r9xmg                                        True     True    Available
   ├─ Usage/configuration-vault-r9xmg-77cpl                                -        True    Available
   ├─ Usage/configuration-vault-r9xmg-qj2r2                                -        True    Available
   ├─ Usage/configuration-vault-r9xmg-rxz68                                -        True    Available
   ├─ Usage/configuration-vault-r9xmg-thxf7                                -        True    Available
   ├─ Usage/configuration-vault-r9xmg-v8tf5                                -        True    Available
   ├─ XAuth/configuration-vault-r9xmg-qswjv                                True     True    Available
   │  ├─ Usage/configuration-vault-r9xmg-hh52k                             -        True    Available
   │  ├─ Backend/configuration-vault-auth-backend-userpass                 True     True    Available
   │  └─ Endpoint/configuration-vault-auth-generic-endpoint                True     True    Available
   ├─ XPolicy/configuration-vault-r9xmg-ct8jb                              True     True    Available
   │  ├─ Policy/configuration-vault-admin-policy                           True     True    Available
   │  └─ Policy/configuration-vault-eaas-client-policy                     True     True    Available
   ├─ XSecret/configuration-vault-r9xmg-f7tz2                              True     True    Available
   │  ├─ SecretBackendKey/configuration-vault-transit-secret-backend-key   True     True    Available
   │  ├─ Mount/configuration-vault-kv-v2-secret-mount                      True     True    Available
   │  └─ Mount/configuration-vault-transit-secret-mount                    True     True    Available
   ├─ XVaultInstall/configuration-vault-r9xmg-8x69p                        True     True    Available
   │  ├─ Usage/configuration-vault-r9xmg-h9fbp                             -        True    Available
   │  ├─ Release/configuration-vault-r9xmg-rptpw                           True     True    Available
   │  ├─ Object/configuration-vault-r9xmg-kh4ss                            True     True    Available
   │  ├─ Object/configuration-vault-r9xmg-kndvh                            True     True    Available
   │  └─ Object/configuration-vault-r9xmg-t8qnp                            True     True    Available
   └─ XVaultUser/configuration-vault-r9xmg-m8hlp                           True     True    Available
      └─ Object/configuration-vault-r9xmg-xgkw2                            True     True    Available
```

## Verify the configuration
The Vault configuration may be verified using the following script.
```
test/verify.sh
```
It demonstrates how to list configured resources including
policies, secrets, and endpoints, and how the demo student
user can encrypt and decrypt information using a payment
Vault transit key.

```
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"
vault login - <<< $VAULT_TOKEN
```
```
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                root
token_accessor       s53hlBdiCUTMQn8WS6ECw4NP
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

```
vault policy list
```
```
admin-policy
default
eaas-client-policy
root
```

```
vault secrets list
```
```
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_769b3270    per-token private secret storage
identity/     identity     identity_d34ef982     identity store
kv-v2/        kv           kv_fd07aac4           Crossplane created secret mount.
secret/       kv           kv_1771f5a7           key/value secret storage
sys/          system       system_e90ffc6f       system endpoints used for control, policy and debugging
transit/      transit      transit_6ff2abac      Crossplane created secret mount.
```

```
vault list transit/keys
```
```
Keys
----
payment
```

Log in as student user, encrypt plain text with transit key, and decrypt.
Note that the output shown, especially the tokens will be different for
you.
```
unset VAULT_TOKEN
```

Below, use password: changeme
```
vault login -method=userpass username=student
```

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.
```
Key                    Value
---                    -----
token                  hvs.CAESIBF-rSjSmFr43dZ8qgSK6U8FGJtKKGsk0O9Vv08zGG0SGh4KHGh2cy5Bbzduc2cwY0FON0hobzFnUzBaOUpFdUc
token_accessor         39JtMXAEBKlqjAX0vd66QGC2
token_duration         768h
token_renewable        true
token_policies         ["admin-policy" "default" "eaas-client-policy"]
identity_policies      []
policies               ["admin-policy" "default" "eaas-client-policy"]
token_meta_username    student
```

Encrypt and store information.
```
vault write transit/encrypt/payment \
    plaintext=$(base64 <<< "1111-2222-3333-4444")
```
```
Key            Value
---            -----
ciphertext     vault:v1:HmEcYSDI/dEHZgNQDC0EoQ58c/V2fNJUQIz3hfayywgriEpfhaqrtHLFqz7J/3Wt
key_version    1
```

Decrypt the information.
```
vault write transit/decrypt/payment \
    ciphertext="<COPY_THE_OUTPUT_CIPHER_FROM_ABOVE>"
```
```
Key          Value
---          -----
plaintext    MTExMS0yMjIyLTMzMzMtNDQ0NAo=
```

Decode the base64 encoded plaintext.
```
base64 --decode <<< "<COPY_THE_BASE64_ENCODED_PLAINTEXT_FROM_ABOVE>"
```

## Clean up
Use the following command to delete the local demo cluster.
```
make cleanup
```
