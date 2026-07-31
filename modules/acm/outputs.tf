output "certificate_arn" {
  description = "ARN of the validated ACM certificate (us-east-1), ready for CloudFront."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
