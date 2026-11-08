output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "app_subnet_ids" {
  value = module.network.app_subnet_ids
}

output "db_subnet_ids" {
  value = module.network.db_subnet_ids
}

output "nat_gateway_id" {
  value = module.network.nat_gateway_id
}

output "security_group_ids" {
  value = {
    alb = module.security.alb_sg_id
    app = module.security.app_sg_id
    db  = module.security.db_sg_id
  }
}

output "app_role_name" {
  value = module.security.app_role_name
}

output "db_address" {
  value = module.data.db_address
}

output "db_secret_arn" {
  value = module.data.db_secret_arn
}

output "files_bucket_name" {
  value = module.data.files_bucket_name
}
