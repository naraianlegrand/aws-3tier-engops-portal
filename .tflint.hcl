# tflint: catches mistakes `terraform validate` can't, e.g. invalid instance types,
# deprecated syntax, unused variables, missing version constraints.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
