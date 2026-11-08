terraform {
  # 1.10+ supports native S3 state locking (use_lockfile), so no DynamoDB lock table is needed.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block: bootstrap uses LOCAL state on purpose.
  # It creates the bucket that will hold remote state for everything else,
  # so it can't store its own state there before the bucket exists (chicken-and-egg).
}
