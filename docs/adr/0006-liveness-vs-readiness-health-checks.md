# ADR 0006: The ALB health check does not check the database

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
The ALB sends health checks to each app instance. If an instance fails them, the ALB stops sending it
traffic, and the Auto Scaling Group (with ELB health checks) terminates and replaces it.

## Options considered
1. **`/health` checks the DB too:** the ALB "knows" when the DB is down. But if RDS has a problem,
   **every** instance fails at once. The ALB has no healthy targets, and the ASG keeps replacing healthy
   servers, which can't fix the database. Replacing instances also slows recovery once the DB is back.
2. **Two endpoints:**
   - `/health` (liveness): "is the app process running?" Used by the ALB.
   - `/health/ready` (readiness): also runs `SELECT 1` on the database. Used by people and monitoring.

## Decision
Option 2. The ALB target group checks `/health`.

## Consequences
- A database outage shows up as errors and alarms (Step 7), not as instances being destroyed in a loop.
- An instance whose app process has crashed or hung is still detected and replaced.
- Same idea as Kubernetes liveness vs. readiness probes.
