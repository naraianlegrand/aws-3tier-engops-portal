# ADR 0005: RDS-managed master password in Secrets Manager

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
The app needs the database password. It must not be in code, in Git, or readable by anyone
who can read the Terraform state file.

## Options considered
1. **Password in `terraform.tfvars`:** stays out of Git, but ends up in plain text in the state file.
2. **`random_password` + `aws_secretsmanager_secret` in Terraform:** never typed by a human,
   but still stored in plain text in the state file.
3. **SSM Parameter Store SecureString:** free, but same state-file problem if Terraform sets the value.
4. **RDS-managed master password (`manage_master_user_password = true`):** RDS generates the password,
   stores it in Secrets Manager, and rotates it (every 7 days by default). Terraform only knows the
   secret's ARN, never the password.

## Decision
Option 4. The EC2 role may call `secretsmanager:GetSecretValue` on that one secret ARN only.
The app reads the secret when it starts.

## Consequences
- The password never exists in code, Git, tfvars, or Terraform state.
- Automatic rotation means the app must re-read the secret if a connection fails with an auth error.
  It should not cache the password forever.
- Cost: about $0.40/month per secret, prorated, and deleted along with the DB on destroy.
- Production would add a dedicated low-privilege app DB user (not the master user) and IAM database authentication.
