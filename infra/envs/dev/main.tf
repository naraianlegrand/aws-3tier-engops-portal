# The dev environment: wires the modules together.

data "aws_caller_identity" "current" {}

locals {
  # Names decided here once, then shared by the modules that create and use them.
  # (e.g. the security module grants access to the bucket the data module creates.)
  files_bucket_name   = "${var.name}-files-${data.aws_caller_identity.current.account_id}"
  ecr_repository_name = "engops-portal"
  app_log_group_name  = "/engops-portal/dev/app"

  # Tags for instances/volumes launched by the ASG (provider default_tags don't reach them).
  common_tags = {
    Project   = "engops-portal"
    Owner     = "karthik"
    Env       = "dev"
    ManagedBy = "terraform"
  }
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

  alb_ingress_cidrs   = var.alb_ingress_cidrs
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

# ----- Which image to run: the ECR repo lives in bootstrap/ (ADR 0007) -----
data "aws_ecr_repository" "app" {
  name = local.ecr_repository_name
}

# Only looked up when no tag is given: the most recently pushed image.
data "aws_ecr_image" "latest" {
  count           = var.app_image_tag == null ? 1 : 0
  repository_name = local.ecr_repository_name
  most_recent     = true
}

locals {
  app_image_tag = var.app_image_tag != null ? var.app_image_tag : data.aws_ecr_image.latest[0].image_tags[0]
  app_image_uri = "${data.aws_ecr_repository.app.repository_url}:${local.app_image_tag}"
}

module "compute" {
  source = "../../modules/compute"

  name = var.name
  tags = local.common_tags

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_subnet_ids        = module.network.app_subnet_ids
  alb_sg_id             = module.security.alb_sg_id
  app_sg_id             = module.security.app_sg_id
  instance_profile_name = module.security.app_instance_profile_name

  image_uri         = local.app_image_uri
  region            = var.region
  db_host           = module.data.db_address
  db_name           = module.data.db_name
  db_secret_arn     = module.data.db_secret_arn
  files_bucket_name = module.data.files_bucket_name
  log_group_name    = local.app_log_group_name
}

# Permanent alerts topic from bootstrap/ (email subscription confirmed once).
data "aws_sns_topic" "alerts" {
  name = "engops-portal-alerts"
}

module "monitoring" {
  source = "../../modules/monitoring"

  name          = var.name
  sns_topic_arn = data.aws_sns_topic.alerts.arn

  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  db_instance_identifier  = module.data.db_instance_identifier
}
