include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules/s3"
}

inputs = {
  bucket_name = "myorg-${local.env_vars.locals.environment}-static-assets"
  environment = local.env_vars.locals.environment
}
