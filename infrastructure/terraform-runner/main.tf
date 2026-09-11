provider "scaleway" {
  project_id = var.project_id
  zone       = var.zone
  region     = "fr-par"
}

resource "scaleway_instance_ip" "runner" {
  project_id = var.project_id
  zone       = var.zone
}

resource "scaleway_instance_security_group" "runner" {
  name        = "devops-runbooks-gh-runner"
  description = "GitHub Actions self-hosted runner"

  project_id = var.project_id
  zone       = var.zone

  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 22
    ip_range = var.operator_cidr
  }
}

resource "scaleway_instance_server" "runner" {
  name  = "devops-runbooks-gh-runner"
  type  = var.runner_type
  image = "ubuntu_jammy"

  project_id = var.project_id
  zone       = var.zone

  ip_id             = scaleway_instance_ip.runner.id
  security_group_id = scaleway_instance_security_group.runner.id

  tags = [
    "github-actions",
    "self-hosted-runner",
    "devops-runbooks",
    "production"
  ]
}
