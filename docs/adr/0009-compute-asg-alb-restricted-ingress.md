# ADR 0009: EC2 Auto Scaling Group behind an ALB, ingress limited to my IP

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
The app container must run in the private app subnets, survive instance failure, scale under load,
and be reachable from a browser. The app has no user authentication yet.

## Decisions
1. **ASG (min 1, max 2) across both app subnets, behind an ALB.** One instance keeps cost low; two AZs
   mean a replacement can launch in the other AZ if one fails.
2. **`health_check_type = "ELB"`.** The ASG trusts the ALB's `/health` checks, so an instance whose app has
   crashed (EC2 still "running") is terminated and replaced. The 300 s grace period covers Docker install and image pull.
3. **Target-tracking scaling on 60% average CPU.** AWS adds or removes instances itself, with no hand-written alarms.
4. **Rolling instance refresh.** A new image tag or AMI creates a new launch-template version, and instances are
   replaced one at a time. With one instance this means a short outage, which is acceptable in dev.
5. **IMDSv2 required, hop limit 2.** Blocks SSRF-style credential theft. Hop limit 2 lets the container reach
   instance-role credentials through Docker's network.
6. **ALB ingress = my IP only (`alb_ingress_cidrs`, set in gitignored tfvars).** With no login, opening it to
   `0.0.0.0/0` would let anyone on the internet read and upload files.
7. **x86 `t3.micro`.** Free-plan eligible, and matches the `linux/amd64` image built by CI.

## Consequences
- Instance failure heals itself. A database outage does not trigger replacement (ADR 0006).
- Each instance runs user data on boot (about 1–3 min) instead of starting from a pre-baked AMI.
  Production would bake an AMI (e.g. with Packer) or use ECS/Fargate.
- Production would add HTTPS (ACM certificate + 443 listener + HTTP→HTTPS redirect), authentication,
  WAF, and `min_size = 2` for zero-downtime deploys.
