# Deployment design

`make deploy` is the single entry point. Terraform owns cloud resources. Ansible owns machine configuration and application deployment. Runtime services are systemd-managed. No service requires an interactive SSH tunnel or terminal to remain open.

The deployment intentionally separates public ingress (Nginx only) from localhost-only AI services. HTTP/80 is retained for ACME HTTP-01 validation; all normal HTTP requests redirect to HTTPS after certificate issuance.
