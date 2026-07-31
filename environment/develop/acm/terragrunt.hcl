include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "${get_repo_root()}/modules/acm"
}

inputs = {
  domain_name    = "${local.env_vars.locals.subdomain}.${get_env("DOMAIN_NAME")}"
  hosted_zone_id = get_env("HOSTED_ZONE_ID")
  environment    = local.env_vars.locals.environment
}
