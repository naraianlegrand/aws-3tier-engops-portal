output "alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.no_healthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.target_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.rds_free_storage.alarm_name,
    aws_cloudwatch_metric_alarm.ec2_cpu_high.alarm_name,
  ]
}
