variable "project_id" {
  description = "Scaleway Project ID"
  type        = string
}

variable "operator_cidr" {
  description = "CIDR allowed to SSH to the GitHub Actions runner"
  type        = string
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-1"
}

variable "runner_type" {
  description = "Scaleway Instance type for the GitHub Actions runner"
  type        = string
  default     = "DEV1-S"
}
