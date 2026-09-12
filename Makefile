.PHONY: help deploy deploy-all redeploy verify status logs reindex access plan fmt destroy destroy-all deploy-local deploy-ci

help:
	@printf '%s\n' \
	  'make deploy      Create/update the application stack' \
	  'make deploy-all  Create/update runner + application stack' \
	  'make redeploy  Idempotently run the full deployment again' \
	  'make verify    Run end-to-end health checks' \
	  'make status    Show services and resources' \
	  'make logs      Follow application logs' \
	  'make reindex   Rebuild the Linux knowledge index' \
	  'make access    Allow the current public IP in SSH/Nginx' \
	  'make plan      Show Terraform plan' \
	  'make destroy     Destroy the application stack' \
	  'make destroy-all Destroy runner + application stack'

deploy:
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
	  && git remote get-url origin >/dev/null 2>&1 \
	  && command -v gh >/dev/null 2>&1 \
	  && gh auth status >/dev/null 2>&1; then \
		echo "GitHub-connected repository detected."; \
		echo; \
		if [ -n "$$(git status --porcelain)" ]; then \
			echo "Local changes detected:"; \
			git status --short; \
			echo; \
			printf "Stage, commit and push these changes? [y/N] "; \
			read answer; \
			case "$$answer" in \
			  y|Y|yes|YES) \
				printf "Commit message [Deploy application changes]: "; \
				read message; \
				if [ -z "$$message" ]; then message="Deploy application changes"; fi; \
				git add -A; \
				git status --short; \
				echo; \
				printf "Confirm commit and push? [y/N] "; \
				read confirm; \
				case "$$confirm" in \
				  y|Y|yes|YES) \
					git commit -m "$$message"; \
					git push origin main; \
					SHA=$$(git rev-parse HEAD); \
					./scripts/watch-deploy.sh commit "$$SHA"; \
					;; \
				  *) echo "Cancelled."; exit 1 ;; \
				esac \
				;; \
			  *) echo "Cancelled."; exit 1 ;; \
			esac; \
		else \
			echo "Repository is clean."; \
			printf "Trigger production deployment? [y/N] "; \
			read answer; \
			case "$$answer" in \
			  y|Y|yes|YES) ./scripts/watch-deploy.sh dispatch ;; \
			  *) echo "Cancelled."; exit 1 ;; \
			esac; \
		fi; \
	else \
		echo "GitHub CI/CD not configured or gh unavailable."; \
		echo "Falling back to local deployment."; \
		./scripts/deploy.sh; \
		echo; \
		echo "Application URL:"; \
		terraform -chdir=infrastructure/terraform output -raw https_url; \
		echo; \
	fi

deploy-all:
	@./scripts/deploy-all.sh



redeploy: deploy

verify:
	@./scripts/verify.sh

status:
	@./scripts/status.sh

logs:
	@./scripts/logs.sh

reindex:
	@./scripts/reindex.sh

access:
	@./scripts/allow-ip.sh

plan:
	@set -eu; \
	CLIENT_IP=$${CLIENT_IP:-$$(curl -4 -fsS https://api.ipify.org)}; \
	PROJECT_ID=$${SCW_PROJECT_ID:-$${TF_VAR_project_id:-}}; \
	if [ -z "$$PROJECT_ID" ] && [ -f infrastructure/terraform/terraform.tfvars ]; then \
	  PROJECT_ID=$$(awk -F'"' '/^[[:space:]]*project_id[[:space:]]*=/ {print $$2; exit}' infrastructure/terraform/terraform.tfvars); \
	fi; \
	if [ -z "$$PROJECT_ID" ]; then printf 'Scaleway Project ID: '; read -r PROJECT_ID; fi; \
	if [ -z "$$PROJECT_ID" ]; then printf '%s\n' 'ERROR: Scaleway Project ID is required.'; exit 1; fi; \
	TF_VAR_project_id=$$PROJECT_ID \
	TF_VAR_ssh_allowed_cidr=$${CLIENT_IP}/32 \
	terraform -chdir=infrastructure/terraform plan

fmt:
	@terraform -chdir=infrastructure/terraform fmt -recursive

destroy:
	@./scripts/destroy.sh


destroy-all:
	@./scripts/destroy-all.sh




deploy-local:
	@./scripts/deploy.sh

deploy-ci:
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "GitHub CLI (gh) is required for deploy-ci."; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "GitHub CLI is not authenticated."; \
		exit 1; \
	fi
	@gh workflow run deploy.yml
