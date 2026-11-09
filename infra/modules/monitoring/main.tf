# Alarms publish to the permanent SNS topic in bootstrap/ (email confirmed once, survives destroy).
locals {
  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  actions = [var.sns_topic_arn]
}

# ---------------------------------------------------------------------------
# 1. No healthy app instances behind the ALB: the app is down for users.
# HealthyHostCount < 1 (not UnHealthyHostCount > 0): when the ASG terminates a broken
# instance, the unhealthy count returns to 0 even though nothing is serving traffic.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  alarm_name          = "${var.name}-no-healthy-hosts"
  alarm_description   = "ALB has no healthy app instances: the portal is down."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = local.alb_dimensions
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching" # no data from the ALB at all is also bad
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---------------------------------------------------------------------------
# 2. ALB-generated 5xx (502/503/504): the ALB couldn't get an answer from any app instance.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB returned more than 5 errors in 5 minutes (no/broken targets)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching" # no errors reported = fine
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---------------------------------------------------------------------------
# 3. App-generated 5xx: the app answered, but with an error (bug, DB unreachable, ...).
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${var.name}-app-5xx"
  alarm_description   = "App returned more than 5 server errors in 5 minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = local.alb_dimensions
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---------------------------------------------------------------------------
# 4. RDS running out of disk.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.name}-rds-low-storage"
  alarm_description   = "RDS free storage below 2 GiB."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_instance_identifier }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_free_storage_threshold_bytes
  treat_missing_data  = "missing"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}

# ---------------------------------------------------------------------------
# 5. Sustained high CPU across the ASG. Target-tracking scaling (60%) should react first;
# this fires if CPU stays high anyway (e.g. already at max_size).
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.name}-ec2-cpu-high"
  alarm_description   = "Average app CPU above 80% for 10 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = var.asg_name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = local.actions
  ok_actions          = local.actions
}
