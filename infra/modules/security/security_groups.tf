# ---------------------------------------------------------------------------
# The security group chain:
#   Allowed IPs --80--> alb-sg --app_port--> app-sg --5432--> db-sg
#
# Rules are separate resources (aws_vpc_security_group_*_rule) instead of inline blocks.
# Why: alb-sg's egress points at app-sg and app-sg's ingress points at alb-sg.
# Inline rules would make the two groups depend on each other (a cycle).
# Separate rules let Terraform create both groups first, then wire the rules.
#
# Note: Terraform removes AWS's default "allow all outbound" rule from groups it creates,
# so each group can send ONLY what its egress rules below allow.
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB: HTTP from the internet, forwards only to app instances"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App EC2: traffic only from the ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "RDS: PostgreSQL only from app instances"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-db-sg" }
}

# ----- alb-sg -----
# One rule per allowed CIDR. While the app has no login, this is the owner's IP only (ADR 0009).
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from allowed client IPs (HTTPS/443 added later if a domain + certificate exist)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests and health checks to app instances only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# ----- app-sg -----
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port only from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to the database only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  # AWS service endpoints (ECR, Secrets Manager, SSM, CloudWatch, S3, OS package repos) don't have
  # fixed IPs, so HTTPS has to be allowed to 0.0.0.0/0. It still leaves via the NAT (or the S3
  # endpoint), and nothing can connect IN through this rule.
  description = "HTTPS to AWS APIs and package repos"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

# ----- db-sg -----
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL only from app instances"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

# db-sg has NO egress rules: the database never needs to start outbound connections.
# (Security groups are stateful, so replies to the app's queries still flow back.)
