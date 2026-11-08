# ADR 0004: Admin access through SSM Session Manager, no SSH

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
I sometimes need a shell on an app instance to debug it. The instances are in private subnets
with no public IPs.

## Options considered
1. **SSH through a bastion host:** an extra EC2 instance in a public subnet with port 22 open.
   It needs key pairs that have to be stored, rotated and shared, and it's one more thing to patch.
2. **EC2 Instance Connect Endpoint:** no bastion, but still uses SSH and port 22 inside the VPC.
3. **SSM Session Manager:** the SSM agent (preinstalled on Amazon Linux) makes an outbound HTTPS
   connection to AWS. I connect with IAM credentials from the console or `aws ssm start-session`.

## Decision
SSM Session Manager. Port 22 is not open in any security group, and there are no key pairs.

## Consequences
- Nothing listens for inbound connections, so there's nothing to brute-force.
- Access is controlled by IAM (who may call `ssm:StartSession`) instead of by who holds a key file.
- Sessions can be logged to CloudWatch/S3 for auditing. Not enabled yet; that would be a production addition.
- Instances need outbound HTTPS to the SSM endpoints (through the NAT here, or SSM VPC endpoints in production).
- The role uses the AWS-managed `AmazonSSMManagedInstanceCore` policy, which includes some
  `Resource: "*"` entries the SSM agent requires.
