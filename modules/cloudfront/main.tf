data "aws_caller_identity" "current" {}

locals {
  standard_tags = merge(var.tags, {
    Name        = var.s3_bucket_id
    Environment = var.environment
    Managed-By  = "terraform"
    CreatedBy   = data.aws_caller_identity.current.arn
    CreatedAt   = timestamp()
    UpdatedBy   = data.aws_caller_identity.current.arn
    UpdatedAt   = timestamp()
  })
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.s3_bucket_id}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Renders the allow-list directly into the CloudFront Function source so the
# function needs no external calls at request time (the JS runtime supports none).
resource "aws_cloudfront_function" "referer_check" {
  count = var.enable_referer_check ? 1 : 0

  name    = "${var.s3_bucket_id}-referer-check"
  runtime = "cloudfront-js-2.0"
  comment = "Blocks requests whose Referer header is not in the allowed list"
  publish = true
  code = templatefile("${path.module}/functions/referer-check.js.tpl", {
    allowed_referers = var.allowed_referers
  })
}

# Module-owned (not AWS-managed) cache policy so TTLs are a tunable input per
# environment/caller rather than fixed by whatever the managed policy defines.
# No query strings/cookies/headers are forwarded into the cache key: the
# referer-check function runs at viewer-request (before the cache lookup), so
# it doesn't need Referer in the cache key, and keeping the key minimal
# maximizes the cache hit ratio for a static-asset origin.
resource "aws_cloudfront_cache_policy" "this" {
  name        = "${var.s3_bucket_id}-cache-policy"
  comment     = "Cache policy for ${var.s3_bucket_id}"
  min_ttl     = var.min_ttl
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = var.domain_aliases
  price_class         = var.price_class
  default_root_object = var.default_root_object != "" ? var.default_root_object : null
  tags                = local.standard_tags

  lifecycle {
    ignore_changes = [tags["CreatedBy"], tags["CreatedAt"]]
  }

  origin {
    domain_name              = var.s3_bucket_regional_domain_name
    origin_id                = var.s3_bucket_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.s3_bucket_id
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = aws_cloudfront_cache_policy.this.id

    dynamic "function_association" {
      for_each = var.enable_referer_check ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.referer_check[0].arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
