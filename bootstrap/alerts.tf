# ---------------------------------------------------------------------------
# Alarm notifications. Lives in bootstrap (never destroyed) so the email subscription is
# confirmed ONCE. The dev environment's CloudWatch alarms publish to this topic.
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:CloudWatch alarms can't publish to a topic encrypted with the AWS-managed aws/sns key; a customer-managed KMS key costs ~$1/month. Alert messages contain no secrets.
  name = "engops-portal-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.budget_alert_email # same inbox as the budget alerts
}
