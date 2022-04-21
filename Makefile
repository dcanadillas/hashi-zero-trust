PLATFORM="x86_64"
OS="linux"
VAULT_VALUES="./hashicorp_values/vault-values-persistent.yaml"
CONSUL_VALUES="./hashicorp_values/consul-values.yaml"
WAYPOINT_VALUES="./hashicorp_values/waypoint-values.yaml"
ABS_VAULT_VALUES := "$(shell cd $(shell dirname $(VAULT_VALUES));pwd)/$(shell basename $(VAULT_VALUES))"
ABS_CONSUL_VALUES := "$(shell cd $(shell dirname $(CONSUL_VALUES));pwd)/$(shell basename $(CONSUL_VALUES))"
ABS_WAYPOINT_VALUES := "$(shell cd $(shell dirname $(WAYPOINT_VALUES));pwd)/$(shell basename $(WAYPOINT_VALUES))"

define usage
	@echo "\nUsage:\n \tmake [all|install|vault|consul|waypoint|clean] \n"
	@echo "\t> all: It does everything (installation and configuration)"
	@echo "\t> install: It deploys Vault, Consul and Waypoint using the current K8s context"
	@echo "\t> vault: It configures Vault with required secrets and auth methods"
	@echo "\t> consul: It deploys Consul CRDs in \"./consul-crds/\" directory"
	@echo "\t> waypoint: It configures Waypoint by creating the context connection and server config"
	@echo "\n--------\n"
endef


.PHONY: all
all: install vault consul waypoint

install:
# @./scripts/01-deploy.sh `realpath $(VAULT_VALUES)` `realpath $(CONSUL_VALUES)` `realpath $(WAYPOINT_VALUES)`
	@echo "\nUsing these values files: \n\n    VAULT: $(ABS_VAULT_VALUES)\n    CONSUL: $(ABS_CONSUL_VALUES)\n    WAYPOINT: $(ABS_WAYPOINT_VALUES)\n"
	@./scripts/01-deploy.sh $(ABS_VAULT_VALUES) $(ABS_CONSUL_VALUES) $(ABS_WAYPOINT_VALUES)

	
vault:
	@./scripts/02-vault-config.sh

waypoint:
	@./scripts/03-waypoint_config.sh

consul:
	kubectl apply -f ./consul-crds/ -n apps

clean:
	@./scripts/clean.sh

help:
	$(call usage)
