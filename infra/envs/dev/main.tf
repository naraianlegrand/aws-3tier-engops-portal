# The dev environment: wires the modules together.

data "aws_caller_identity" "current" {}

locals {
  # Names decided here once, then shared by the modules that create and use them.
  # (e.g. the security module grants access to the bucket the data module creates in Step 4.)
  files_bucket_name   = "${var.name}-files-${data.aws_caller_identity.current.account_id}"
  ecr_repository_name = "engops-portal"
  app_log_group_name  = "/engops-portal/dev/app"
}

module "network" {
  source = "../../modules/network"

  name     = var.name
  vpc_cidr = "10.0.0.0/16"
  azs      = var.azs

  # Numbering scheme: 0-9 public, 10-19 app, 20-29 db. Easy to read in the console.
  public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  app_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  db_subnet_cidrs     = ["10.0.20.0/24", "10.0.21.0/24"]

  enable_nat_gateway = var.enable_nat_gateway
}

module "security" {
  source = "../../modules/security"

  name   = var.name
  vpc_id = module.network.vpc_id

  app_port            = 8000
  files_bucket_name   = local.files_bucket_name
  ecr_repository_name = local.ecr_repository_name
  app_log_group_name  = local.app_log_group_name
  db_secret_arn       = module.data.db_secret_arn
}

# Note: data uses security's db-sg, and security uses data's secret ARN.
# That's fine: Terraform orders individual resources, not whole modules
# (db-sg -> RDS -> secret -> IAM policy), so there's no cycle.
module "data" {
  source = "../../modules/data"

  name          = var.name
  db_subnet_ids = module.network.db_subnet_ids
  db_sg_id      = module.security.db_sg_id

  files_bucket_name    = local.files_bucket_name
  force_destroy_bucket = true # dev only: destroy after every demo
}
