# Project Setup
PROJECT_NAME := configuration-vault
PROJECT_REPO := github.com/upbound/$(PROJECT_NAME)

# NOTE(hasheddan): the platform is insignificant here as Configuration package
# images are not architecture-specific. We constrain to one platform to avoid
# needlessly pushing a multi-arch image.
PLATFORMS ?= linux_amd64
-include build/makelib/common.mk

# ====================================================================================
# Setup Kubernetes tools

KUBECTL_VERSION = v1.27.3
UP_VERSION = v0.21.0
UP_CHANNEL = stable
UPTEST_VERSION = v0.10.0
-include build/makelib/k8s_tools.mk
# ====================================================================================
# Setup XPKG

# NOTE(jastang): Configurations deployed in Upbound do not currently follow
# certain conventions such as the default examples root or package directory.
XPKG_DIR = $(shell pwd)
XPKG_EXAMPLES_DIR = examples
XPKG_IGNORE = .github/workflows/ci.yaml,.github/workflows/tag.yml,.github/workflows/e2e.yaml,.github/workflows/yamllint.yaml,init/*.yaml,.work/uptest-datasource.yaml,test/provider/*.yaml,examples/*.yaml

XPKG_REG_ORGS ?= xpkg.upbound.io/upbound
# NOTE(hasheddan): skip promoting on xpkg.upbound.io as channel tags are
# inferred.
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/upbound
XPKGS = $(PROJECT_NAME)
-include build/makelib/xpkg.mk

CROSSPLANE_NAMESPACE = upbound-system
CROSSPLANE_ARGS = "--enable-usages"
KIND_CLUSTER_NAME = "uxp"
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk

# ====================================================================================
# Targets

# run `make help` to see the targets and options

# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

# Update the submodules, such as the common build scripts.
submodules:
	@git submodule sync
	@git submodule update --init --recursive

# We must ensure up is installed in tool cache prior to build as including the k8s_tools machinery prior to the xpkg
# machinery sets UP to point to tool cache.
build.init: $(UP)

# ====================================================================================
# End to End Testing

# This target requires the following environment variables to be set:
# - UPTEST_CLOUD_CREDENTIALS, cloud credentials for the provider being tested, e.g. export UPTEST_CLOUD_CREDENTIALS=$(cat ~/.aws/credentials)
# - To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately. 
#   You can check the basic implementation here: https://github.com/upbound/uptest/blob/main/internal/templates/01-delete.yaml.tmpl.
uptest: $(UPTEST) $(KUBECTL) $(KUTTL)
	@$(INFO) running automated tests
	@KUBECTL=$(KUBECTL) CROSSPLANE_NAMESPACE=$(CROSSPLANE_NAMESPACE) KUTTL=$(KUTTL) $(UPTEST) e2e examples/vault.yaml --setup-script=test/setup.sh --skip-delete --default-timeout=3600 || $(FAIL)
	@$(OK) running automated tests

# This target requires the following environment variables to be set:
# - UPTEST_CLOUD_CREDENTIALS, cloud credentials for the provider being tested, e.g. export UPTEST_CLOUD_CREDENTIALS=$(cat ~/.aws/credentials)
e2e: build controlplane.up local.xpkg.deploy.configuration.$(PROJECT_NAME) uptest

s = "False"
bootstrap: build controlplane.up local.xpkg.deploy.configuration.$(PROJECT_NAME)
	test/setup.sh
	$(KUBECTL) apply -f examples/vault.yaml
	s=$(s); \
        while [ $${s} != "True" ] ; do \
	    $(KUBECTL) wait vault.sec.upbound.io configuration-vault --for=condition=Ready --timeout 20m ; \
	    sleep 3 ; \
	    s=`$(KUBECTL) get vault.sec.upbound.io configuration-vault -o jsonpath='{.status.conditions[1].status}'|awk '{print $1}'`; \
	    echo $$s ; \
        done; \
        true
	$(KUBECTL) -n vault port-forward vault-0 8200 2>&1 >/dev/null &
	crossplane beta trace vault.sec.upbound.io configuration-vault
	test/verify.sh

verify:
	$(KUBECTL) -n vault port-forward vault-0 8200 2>&1 >/dev/null &
	test/verify.sh

cleanup:
	kind delete cluster --name uxp

render:
	crossplane beta render examples/vault.yaml apis/vault/composition.yaml examples/functions.yaml -r

yamllint:
	@$(INFO) running yamllint
	@yamllint ./apis || $(FAIL)
	@$(OK) running yamllint

.PHONY: uptest e2e bootstrap
