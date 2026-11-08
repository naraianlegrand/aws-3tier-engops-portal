# Credentials come from the AWS_PROFILE environment variable, not from code.
# PowerShell:  $env:AWS_PROFILE = "engops"
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "engops-portal"
      Owner     = "karthik"
      Env       = "dev"
      ManagedBy = "terraform"
    }
  }
}
