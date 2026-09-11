output "server_id" {
  description = "Scaleway server ID"
  value       = scaleway_instance_server.main.id
}

output "server_name" {
  description = "Server name"
  value       = scaleway_instance_server.main.name
}

output "server_type" {
  description = "Server type"
  value       = scaleway_instance_server.main.type
}

output "public_ip" {
  description = "Public IPv4 address"
  value       = scaleway_instance_ip.main.address
}

output "data_volume_id" {
  description = "Data volume ID"
  value       = scaleway_block_volume.data.id
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh root@${scaleway_instance_ip.main.address}"
}

output "https_url" {
  description = "Runbook AI HTTPS URL"
  value       = "https://${element(reverse(split("/", scaleway_instance_server.main.id)), 0)}.pub.instances.scw.cloud"
}
