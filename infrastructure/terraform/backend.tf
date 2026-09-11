terraform {
  backend "s3" {
    bucket = "cheikhailabs-devops-runbooks-tfstate-4b5df351"
    key    = "production/terraform.tfstate"
    region = "fr-par"

    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }

    use_lockfile = true

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
