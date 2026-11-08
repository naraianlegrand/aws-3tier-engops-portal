output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "app_role_name" {
  description = "Step 4 attaches the DB-secret read permission to this role."
  value       = aws_iam_role.app.name
}

output "app_instance_profile_name" {
  description = "Used by the launch template in Step 6."
  value       = aws_iam_instance_profile.app.name
}
