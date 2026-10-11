SHELL := /bin/bash
ENV ?= lab
# plan = read-only token (PVEAuditor); apply/destroy switch to the apply token.
TOKEN ?= plan
# Site values and secrets: Proton Pass references in homelab.env, resolved only for the one command.
RUN = pass-cli run --env-file homelab.env --
TOFU = PROXMOX_VE_API_TOKEN=pass://Homelab/proxmox-tofu-$(TOKEN)/password TF_WORKSPACE=$(ENV) $(RUN) tofu -chdir=tofu
PLAYBOOK = $(RUN) ansible-playbook -i ansible/inventory/$(ENV).yml

.PHONY: login init plan apply destroy guests devices-check config config-check apps release host-check host pin-kernel unpin-kernel lint leak-check ha-check ha-deploy

# Read-only: what pve_host would change on the real host.
host-check: login
	$(PLAYBOOK) ansible/playbooks/pve-host.yml --check --diff

host: login
	$(PLAYBOOK) ansible/playbooks/pve-host.yml --diff

# Guests: OpenTofu creates them, then Ansible adds the root-only config (restarts changed CTs).
guests: apply
	$(PLAYBOOK) ansible/playbooks/guests.yml --diff

devices-check: login
	$(PLAYBOOK) ansible/playbooks/guests.yml --check --diff

config: login
	$(PLAYBOOK) ansible/playbooks/config.yml --diff

# Core stacks (Traefik, Authelia, Dockhand, Hawser), stack secrets, and Dockhand's own setup.
apps: login
	$(PLAYBOOK) ansible/playbooks/apps.yml --diff

# Dockhand deploys the `deploy` branch, never main: advance it only to a commit CI passed.
release:
	@git fetch -q origin main
	@[ "$$(gh run list -w ci -b main -L1 --json headSha,conclusion -q '.[0].headSha+" "+.[0].conclusion')" = \
	  "$$(git rev-parse origin/main) success" ] || { echo "CI on origin/main is not green (yet)"; exit 1; }
	git push origin origin/main:refs/heads/deploy

# Read-only dry run against today's containers: they have no SSH keys, so go through the host (pct exec).
config-check: login
	$(PLAYBOOK) ansible/playbooks/config.yml --check --diff -e pct_remote=true $(ARGS)

# For when a new kernel breaks something (e.g. iGPU): make pin-kernel VERSION=6.17.13-21-pve
pin-kernel: login
	$(RUN) bash -c 'ssh root@$$PVE_IP proxmox-boot-tool kernel pin $(VERSION)'

unpin-kernel: login
	$(RUN) bash -c 'ssh root@$$PVE_IP proxmox-boot-tool kernel unpin'

# PAT sessions last 2h; re-login from the macOS Keychain when needed. An expired session still counts as
# "authenticated" and refuses a new login, so log out first.
login:
	@pass-cli vault list >/dev/null 2>&1 || { pass-cli logout >/dev/null 2>&1; \
	  PROTON_PASS_PERSONAL_ACCESS_TOKEN="$$(security find-generic-password -s proton-pass-pat -w)" pass-cli login; }

init: login
	$(RUN) tofu -chdir=tofu init -input=false
	$(RUN) tofu -chdir=tofu workspace select -or-create $(ENV)

# Each ENV has its own workspace, so its own encrypted state: tofu/terraform.tfstate.d/<ENV>/
plan: login
	$(TOFU) plan -var-file=$(ENV).tfvars

apply destroy: TOKEN = apply
apply destroy: login
	@[ "$(ENV)" != prod ] || [ "$(CONFIRM)" = yes ] || \
	  { echo "refusing $@ ENV=prod without CONFIRM=yes"; exit 1; }
	$(TOFU) $@ -var-file=$(ENV).tfvars
	@[ "$(ENV)" != lab ] || rm -f .lab_known_hosts # CT 990 gets a new host key with every rebuild
	@[ -z "$$(git status --porcelain -- tofu/terraform.tfstate.d/$(ENV))" ] || \
	  echo "*** The encrypted state changed: commit and push tofu/terraform.tfstate.d/$(ENV) ***"

# Same checks as CI. tofu validate gets dummy vars: it never touches state or the API.
lint: export TF_VAR_state_passphrase = ci-dummy-passphrase
lint: export TF_VAR_pve_ip = 192.0.2.1
lint: export TF_VAR_lan_cidr = 192.0.2.0/24
lint: export TF_VAR_gateway = 192.0.2.254
lint: export TF_VAR_dns_vip = 192.0.2.53
lint: leak-check
	yamllint .
	stacks/check.sh
	ansible-lint ansible/
	tofu fmt -check -recursive tofu
	tofu -chdir=tofu init -input=false -backend=false >/dev/null
	tofu -chdir=tofu validate
	@for f in $$(git ls-files '*.tfstate'); do \
	  jq -e 'has("encrypted_data")' "$$f" >/dev/null || { echo "PLAINTEXT STATE: $$f"; exit 1; }; done
	gitleaks git --no-banner .
	trivy config --quiet --exit-code 1 .

# HA's config check on homeassistant/config/ (needs Docker; CI runs it on every push).
ha-check:
	homeassistant/check.sh

# git -> Home Assistant (VM 102) via the Terminal & SSH add-on; restarts HA.
ha-deploy: login
	$(RUN) homeassistant/deploy.sh

# The repo is public: no LAN address may be tracked, and (where homelab.env exists) none of its plain values.
leak-check:
	@! git grep -nE '192\.168\.[0-9]+\.[0-9]+' || { echo "LAN address in a tracked file (use homelab.env)"; exit 1; }
	@[ ! -f homelab.env ] || sed -n 's/^[A-Z_]*=//p' homelab.env | grep -v '^pass://' | awk 'length >= 6' | sort -u | \
	  while IFS= read -r v; do ! git grep -lF -- "$$v" || { echo "a homelab.env value is in the files above"; exit 1; }; done
