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

