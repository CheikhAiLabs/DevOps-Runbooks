# Validation status

## Local checks for the chat/OCR and Scaleway FQDN patches (2026-09-11)

The following checks passed in the existing repository:

- `terraform -chdir=infrastructure/terraform fmt -recursive`
- `python3 -m py_compile` for the API, four indexer scripts, and model download helper (bytecode output redirected to `/tmp`).
- `bash -n` separately for every `scripts/*.sh` file.
- `.deploy-venv/bin/ansible-playbook -i 'localhost,' infrastructure/ansible/playbook.yml --syntax-check`, with the repository Ansible configuration and temporary directories under `/tmp`.

Ansible initially failed to initialize the inherited locale. The syntax check passed with `LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8`; no repository or system locale settings were changed.

No dependency installation, frontend build, model loading, OCR execution, network health check, Terraform plan/apply/destroy, or remote Ansible task was run. Existing Terraform state and runtime data were preserved. Browser behavior and cloud deployment remain unverified.

## Previous candidate notes

Static validation recorded for the earlier generated deployment candidate:

- Python source files compile successfully.
- Shell scripts pass `bash -n` syntax validation.
- Ansible playbook parses as valid YAML.
- Runtime snapshots, Terraform state, local tfvars, plan files and hard-coded deployment IP addresses were removed from the distributable repository.
- The API citation-cleaning expressions were corrected so `[Source N]` markers are removed before rendering; source metadata remains available to the UI cards.
- UI small/medium typography was increased while preserving the existing large hero heading.

Any subsequent cloud deployment or destructive validation requires explicit operator approval. The local checks above do not establish successful deployment or certificate issuance.
