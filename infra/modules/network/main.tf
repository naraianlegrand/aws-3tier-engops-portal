data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# VPC: our private network inside AWS
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Needed so instances get DNS names and can resolve AWS endpoints (RDS, S3, etc.).
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

# Lock down the VPC's default security group (it allows all traffic by default).
# Nothing should use it; we create our own SGs in the security module.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-sg-unused" }
  # No ingress/egress blocks = all rules removed.
}

# Internet Gateway: the VPC's two-way door to the internet (used by public subnets only).
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# ---------------------------------------------------------------------------
# Subnets: 3 tiers x 2 AZs = 6 subnets
# count creates one subnet per AZ; count.index (0, 1) picks the matching AZ and CIDR.
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.public_subnet_cidrs[count.index]

  # Even in public subnets, nothing gets a public IP automatically.
  # The ALB and NAT get their own managed public addresses.
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-public-${var.azs[count.index]}", Tier = "public" }
}

resource "aws_subnet" "app" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]

  tags = { Name = "${var.name}-app-${var.azs[count.index]}", Tier = "app" }
}

resource "aws_subnet" "db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = var.db_subnet_cidrs[count.index]

  tags = { Name = "${var.name}-db-${var.azs[count.index]}", Tier = "db" }
}

# ---------------------------------------------------------------------------
# NAT Gateway: one-way door OUT for the private app subnets.
# One NAT in the first AZ only (cost vs. HA tradeoff, see ADR 0003).
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id # NAT lives in a PUBLIC subnet so it can reach the IGW.

  tags = { Name = "${var.name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Route tables: the "signposts" that decide where traffic goes.
# ---------------------------------------------------------------------------

# Public: anything not inside the VPC goes to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App: outbound internet goes through the NAT (only if enabled). S3 goes via the endpoint.
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-app" }
}

resource "aws_route" "app_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "app" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# DB: NO route to the internet at all. Only the built-in "local" route (inside the VPC).
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-db" }
}

resource "aws_route_table_association" "db" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ---------------------------------------------------------------------------
# S3 Gateway Endpoint (free): app instances reach S3 over AWS's private network,
# not through the NAT. Saves NAT data charges and keeps S3 traffic off the internet.
# ---------------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]

  tags = { Name = "${var.name}-s3-endpoint" }
}
