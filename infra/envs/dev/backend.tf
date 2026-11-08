# Remote state in the bucket created by bootstrap/.
# Backend blocks can't use variables, so values are written out here.
# (AWS account IDs are identifiers, not secrets.)
terraform {
  backend "s3" {
    bucket       = "engops-portal-tfstate-754906231711"
    key          = "dev/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true # native S3 locking: a .tflock object blocks a second concurrent apply
  }
}
