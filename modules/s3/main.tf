data "aws_caller_identity" "current" {}

locals {
  standard_tags = merge(var.tags, {
    Environment = var.environment
    Managed-By  = "terraform"
    CreatedBy   = data.aws_caller_identity.current.arn
    CreatedAt   = timestamp()
    UpdatedBy   = data.aws_caller_identity.current.arn
    UpdatedAt   = timestamp()
  })
}

# A custom key policy is required (not just the S3 bucket policy) because
# CloudFront's OAC request is made as the `cloudfront.amazonaws.com` service
# principal, which the default KMS key policy does not grant kms:Decrypt to.
# Without this, CloudFront gets a KMS.AccessDeniedException when serving
# SSE-KMS-encrypted objects even though the S3 bucket policy allows the read.
# Statement 1 (root account access) must be included explicitly: setting any
# custom `policy` on aws_kms_key replaces the default policy entirely.
data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudFrontOACDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "KMS key for S3 bucket ${var.bucket_name}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = merge(local.standard_tags, { Name = "${var.bucket_name}-kms" })

  lifecycle {
    ignore_changes = [tags["CreatedBy"], tags["CreatedAt"]]
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/s3/${var.bucket_name}"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = merge(local.standard_tags, { Name = var.bucket_name })

  lifecycle {
    ignore_changes = [tags["CreatedBy"], tags["CreatedAt"]]
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: CloudFront access is scoped by AWS account (AWS:SourceAccount), not by a
# specific distribution ARN, to avoid a circular dependency between this module
# and the cloudfront module (the distribution doesn't exist yet when this bucket
# policy is first created). See plan's "Key Design Decision" for the trade-off.
data "aws_iam_policy_document" "this" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
