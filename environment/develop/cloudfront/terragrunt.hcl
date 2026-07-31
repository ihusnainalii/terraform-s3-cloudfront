include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules/cloudfront"
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs = {
    bucket_id                   = "mock-bucket"
    bucket_regional_domain_name = "mock-bucket.s3.us-east-1.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate", "init"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/mock"
  }
  mock_outputs_allowed_terraform_commands = ["plan", "validate", "init"]
}

inputs = {
  s3_bucket_id                    = dependency.s3.outputs.bucket_id
  s3_bucket_regional_domain_name  = dependency.s3.outputs.bucket_regional_domain_name
  acm_certificate_arn             = dependency.acm.outputs.certificate_arn
  domain_aliases                  = ["${local.env_vars.locals.subdomain}.${get_env("DOMAIN_NAME")}"]
  allowed_referers                = ["https://${local.env_vars.locals.subdomain}.${get_env("DOMAIN_NAME")}"]
  environment                     = local.env_vars.locals.environment
}
