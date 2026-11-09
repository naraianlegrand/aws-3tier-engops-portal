output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_arn_suffix" {
  description = "Used by CloudWatch alarms in Step 7."
  value       = aws_lb.app.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.app.arn_suffix
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
