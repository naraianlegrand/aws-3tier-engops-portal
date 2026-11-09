# ---------------------------------------------------------------------------
# RDS PostgreSQL: the data tier for the request tracker.
# ---------------------------------------------------------------------------

# Tells RDS which subnets it may use: the private DB subnets in both AZs.
resource "aws_db_subnet_group" "this" {
  name        = "${var.name}-db"
  description = "Private DB subnets for ${var.name}"
  subnet_ids  = var.db_subnet_ids
  tags        = { Name = "${var.name}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Dev cost - Multi-AZ doubles the price. Production: multi_az = true (ADR 0003 / README known gaps).
  #checkov:skip=CKV_AWS_293:Dev - destroyed after every session. Production: deletion_protection = true.
  #checkov:skip=CKV_AWS_118:Dev cost - enhanced monitoring needs an extra IAM role and bills CloudWatch. Basic RDS metrics are used for alarms.
  #checkov:skip=CKV_AWS_129:Dev cost - exporting PostgreSQL logs bills CloudWatch ingestion. Production: export postgresql logs.
  #checkov:skip=CKV2_AWS_30:Dev cost - same as CKV_AWS_129 (query logging via log export).
  #checkov:skip=CKV_AWS_353:Dev - Performance Insights not needed for a demo workload.
  #checkov:skip=CKV_AWS_161:App authenticates with the RDS-managed Secrets Manager password (ADR 0005). Production: IAM database authentication for the app user.
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username

  # RDS generates the password and stores it in Secrets Manager (see ADR 0005).
  # It never appears in code, Git, or Terraform state.
  manage_master_user_password = true

  # Storage: small, encrypted at rest (AWS-managed KMS key, no extra cost).
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  # Network: private only, reachable only through db-sg (5432 from app-sg).
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false

  # One instance in one AZ (cost). Production: multi_az = true for automatic failover.
  multi_az = false

  # Backups: keep 1 day of automated backups (point-in-time restore talking point).
  backup_retention_period = 1
  copy_tags_to_snapshot   = true

  # Dev settings so `terraform destroy` works in one command.
  # Production: deletion_protection = true, skip_final_snapshot = false.
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  auto_minor_version_upgrade = true

  tags = { Name = "${var.name}-postgres" }
}
