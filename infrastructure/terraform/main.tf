resource "scaleway_instance_ip" "main" {
  type = "routed_ipv4"
  zone = var.zone
  tags = var.tags
}

resource "scaleway_instance_security_group" "main" {
  name                    = "${var.server_name}-sg"
  description             = "Security group for DevOps Runbooks RAG platform"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true
  zone                    = var.zone
  tags                    = var.tags

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 22
    ip_range = var.ssh_allowed_cidr
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 80
    ip_range = "0.0.0.0/0"
  }

  inbound_rule {
    action   = "accept"
    protocol = "TCP"
    port     = 443
    ip_range = "0.0.0.0/0"
  }
}

resource "scaleway_block_volume" "data" {
  name       = "${var.server_name}-data"
  zone       = var.zone
  size_in_gb = var.data_disk_size_gb
  iops       = var.data_disk_iops
  tags       = var.tags
}

resource "scaleway_instance_server" "main" {
  name  = var.server_name
  type  = var.server_type
  image = var.image
  zone  = var.zone

  ip_id             = scaleway_instance_ip.main.id
  security_group_id = scaleway_instance_security_group.main.id

  additional_volume_ids = [
    scaleway_block_volume.data.id
  ]

  root_volume {
    volume_type           = "sbs_volume"
    size_in_gb            = var.root_disk_size_gb
    sbs_iops              = 5000
    delete_on_termination = true
  }

  user_data = {
    cloud-init = file("${path.module}/cloud-init.yaml")
  }

  boot_type = "local"
  state     = "started"

  tags = var.tags
}
