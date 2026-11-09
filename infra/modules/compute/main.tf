# ---------------------------------------------------------------------------
# Log group the app containers write to (Docker awslogs driver).
# Created here because the instances need it from their first boot; Step 7 adds alarms.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = var.log_group_name
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# AMI: latest Amazon Linux 2023 for x86_64 (SSM agent and AWS CLI preinstalled).
# Note: when AWS publishes a new AMI, the next plan shows a launch template change.
# ---------------------------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------------------------------------------------------------------
# Launch template: the recipe every ASG instance is built from.
# ---------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name                   = "${var.name}-app"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  update_default_version = true

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # Private only: no public IP, only app-sg.
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
  }

  # IMDSv2 required: blocks SSRF-style theft of the instance role credentials.
  # Hop limit 2 so the Docker container (one network hop further) can still get role credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Encrypted root volume.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    registry          = split("/", var.image_uri)[0]
    image_uri         = var.image_uri
    region            = var.region
    app_port          = var.app_port
    log_group_name    = var.log_group_name
    db_host           = var.db_host
    db_name           = var.db_name
    db_secret_arn     = var.db_secret_arn
    files_bucket_name = var.files_bucket_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  # The log group must exist before an instance starts shipping logs to it.
  depends_on = [aws_cloudwatch_log_group.app]
}

# ---------------------------------------------------------------------------
# ALB: the public entry point (presentation tier), in the public subnets.
# ---------------------------------------------------------------------------
resource "aws_lb" "app" {
  name                       = "${var.name}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = var.public_subnet_ids
  security_groups            = [var.alb_sg_id]
  drop_invalid_header_fields = true
  enable_deletion_protection = false # dev: destroyed after every session
}

resource "aws_lb_target_group" "app" {
  name                 = "${var.name}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30 # seconds to finish in-flight requests before an instance is removed

  # Liveness only, no DB check (ADR 0006).
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------------------------------------------------------------------------
# Auto Scaling Group: keeps 1-2 healthy instances across both private app subnets.
# ---------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-app"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.app_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  # "ELB": if the ALB marks an instance unhealthy, the ASG terminates and replaces it.
  # Grace period: give a new instance time to install Docker and pull the image first.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # New image tag or AMI -> new launch template version -> instances replaced one at a time.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
}

# Scale on CPU: AWS adds an instance when average CPU stays above the target, removes it when it drops.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_percent
  }
}
