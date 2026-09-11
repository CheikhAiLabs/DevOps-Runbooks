variable "project_id" {
  description = "Scaleway Project ID where resources will be created"
  type        = string
}

variable "zone" {
  description = "Scaleway Availability Zone"
  type        = string
  default     = "fr-par-1"
}

variable "region" {
  description = "Scaleway Region"
  type        = string
  default     = "fr-par"
}

variable "server_name" {
  description = "Instance name"
  type        = string
  default     = "devops-runbooks-ai"
}

variable "server_type" {
  description = "Instance commercial type"
  type        = string
  default     = "COMPUTE3-X96C-192G"
}

variable "image" {
  description = "Operating system image"
  type        = string
  default     = "ubuntu_noble"
}

variable "root_disk_size_gb" {
  description = "Root disk size"
  type        = number
  default     = 100
}

variable "data_disk_size_gb" {
  description = "RAG data disk size"
  type        = number
  default     = 500
}

variable "data_disk_iops" {
  description = "Block Storage IOPS"
  type        = number
  default     = 5000
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to access SSH"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = list(string)

  default = [
    "devops-runbooks",
    "rag",
    "ai",
    "terraform",
    "production-lab"
  ]
}


variable "runner_cidr" {
  description = "CIDR of the persistent GitHub Actions self-hosted runner"
  type        = string
  default     = null
}
