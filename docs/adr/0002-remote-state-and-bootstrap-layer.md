# ADR 0002: S3 remote state with native locking, and a separate bootstrap layer

- **Status:** Accepted
- **Date:** 2026-11-07

## Context
Terraform must remember what it created (the state file). That file has to be stored safely,
shared between my laptop and GitHub Actions, and protected from two applies running at once.
The dev environment is destroyed after every demo, but some things must outlive it.

## Options considered
1. **Local state file:** simple, but it lives on one laptop, CI can't see it, and there's no locking.
2. **S3 + DynamoDB lock table:** the classic pattern. DynamoDB locking is now deprecated in Terraform.
3. **S3 with native locking (`use_lockfile = true`, Terraform 1.10+):** one bucket, and a `.tflock`
   object acts as the lock. No extra service.

## Decision
Option 3. A separate `bootstrap/` Terraform root (local state, applied once, never destroyed)
creates the state bucket **and the AWS Budgets alert**.

## Consequences
- If two applies run at once, the second fails to acquire the lock instead of corrupting state.
- Versioning lets me roll back a bad state file.
- The budget lives in bootstrap, so `terraform destroy` in dev never removes the cost guard.
- Bootstrap's own state is local. If it's lost, the bucket and budget can be re-imported.
- Production would add a KMS key, access logging, and separate state per environment/account.
