output "runner_id" {
  value = scaleway_instance_server.runner.id
}

output "runner_public_ip" {
  value = scaleway_instance_ip.runner.address
}

output "runner_cidr" {
  value = "${scaleway_instance_ip.runner.address}/32"
}

output "security_group_id" {
  value = scaleway_instance_security_group.runner.id
}
