# NOTE: ACM certificates used by CloudFront must be requested in us-east-1
# regardless of the region the rest of the stack runs in. The caller (via the
# Terragrunt-generated root provider block) must supply an `aws.us_east_1`
# provider alias to this module.

data "aws_caller_identity" "current" {}

locals {
  standard_tags = merge(var.tags, {
    Name        = var.domain_name
    Environment = var.environment
    Managed-By  = "terraform"
    CreatedBy   = data.aws_caller_identity.current.arn
    CreatedAt   = timestamp()
    UpdatedBy   = data.aws_caller_identity.current.arn
    UpdatedAt   = timestamp()
  })
}

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"
  tags                      = local.standard_tags

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["CreatedBy"], tags["CreatedAt"]]
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}
