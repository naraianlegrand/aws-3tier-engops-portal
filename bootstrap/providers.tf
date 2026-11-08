# Credentials come from the AWS_PROFILE environment variable, not from code.
# PowerShell:  $env:AWS_PROFILE = "engops"
provider "aws" {
  region = var.region

  # Every resource this provider creates gets these tags automatically.
  default_tags {
    tags = {
      Project   = "engops-portal"
      Owner     = "karthik"
      Env       = "dev"
      ManagedBy = "terraform"
      Layer     = "bootstrap"
    }
  }
}
