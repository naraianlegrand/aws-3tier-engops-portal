output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "For the ALB."
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "For the EC2 Auto Scaling Group."
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "For the RDS DB subnet group."
  value       = aws_subnet.db[*].id
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "nat_gateway_id" {
  value = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : null
}
