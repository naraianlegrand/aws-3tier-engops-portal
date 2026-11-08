# The dev environment: wires the modules together.
# Later steps add security, data, compute and monitoring modules here.

module "network" {
  source = "../../modules/network"

  name     = var.name
  vpc_cidr = "10.0.0.0/16"
  azs      = var.azs

  # Numbering scheme: 0-9 public, 10-19 app, 20-29 db. Easy to read in the console.
  public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  app_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  db_subnet_cidrs     = ["10.0.20.0/24", "10.0.21.0/24"]

  enable_nat_gateway = var.enable_nat_gateway
}
