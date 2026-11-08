# ADR 0003: One NAT Gateway shared by both AZs

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
EC2 instances in the private app subnets need outbound internet access (ECR image pulls,
Secrets Manager, CloudWatch, OS updates) without being reachable from the internet.
This is a learning/demo project on a Free-plan account, deployed and destroyed the same day.

## Options considered
1. **NAT Gateway per AZ (2):** the production pattern. Survives an AZ outage. Costs 2 × ~$0.05/hr plus 2 public IPs.
2. **One NAT Gateway (in AZ-a):** half the cost. If AZ-a goes down, AZ-b instances lose outbound access.
3. **NAT instance (self-managed EC2):** about 10× cheaper, but I'd have to patch it, configure iptables
   and disable source/destination checks, and it's still a single point of failure.
4. **VPC interface endpoints only:** about 6 endpoints × 2 AZs × ~$0.01/hr each costs more than one NAT here.

## Decision
One AWS-managed NAT Gateway in the first public subnet. Both app subnets route `0.0.0.0/0` to it.
An `enable_nat_gateway` variable can switch it off.

## Consequences
- Cost: ~$0.05/hr + ~$0.005/hr for the Elastic IP, billed only while deployed.
  Partial hours are billed as full hours.
- Inbound traffic still can't reach private instances. The NAT only allows connections started from inside.
- S3 traffic bypasses the NAT through a free S3 Gateway Endpoint, which saves NAT data-processing charges.
- AZ-a is a single point of failure for outbound traffic. The ALB and app still serve requests from
  AZ-b, but new instances there couldn't pull images.
- **Production change:** one NAT per AZ, each AZ's app subnet routing to its own NAT.
