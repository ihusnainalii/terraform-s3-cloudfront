remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = get_env("TF_STATE_BUCKET")
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = get_env("AWS_REGION")
    encrypt      = true
    use_lockfile = true
  }
}

# `aws.us_east_1` is required by modules/acm — ACM certs for CloudFront must be
# requested in us-east-1 regardless of the primary region. Generated here so
# every unit that includes this root config gets both provider instances.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${get_env("AWS_REGION")}"

  default_tags {
    tags = {
      Managed-By = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Managed-By = "terraform"
    }
  }
}
EOF
}
