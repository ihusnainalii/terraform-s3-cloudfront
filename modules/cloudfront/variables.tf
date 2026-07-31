variable "s3_bucket_id" {
  type        = string
  description = "ID (name) of the S3 bucket to use as the CloudFront origin."
}

variable "environment" {
  type        = string
  description = "Deployment environment name, used for the Environment tag."

  validation {
    condition     = contains(["develop", "staging", "production"], var.environment)
    error_message = "environment must be one of: develop, staging, production."
  }
}

variable "s3_bucket_regional_domain_name" {
  type        = string
  description = "Regional domain name of the S3 bucket origin."
}

variable "domain_aliases" {
  type        = list(string)
  description = "Custom domain names (CNAMEs) to associate with the distribution."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate (must be in us-east-1) to use for the distribution."
}

variable "allowed_referers" {
  type        = list(string)
  description = "List of Referer header value prefixes allowed to access this distribution via the viewer-request CloudFront Function. A request whose Referer does not start with one of these values (or has no Referer at all) is denied with 403. An empty list denies all requests. Ignored if enable_referer_check is false."
  default     = []
}

variable "enable_referer_check" {
  type        = bool
  description = "Whether to attach the referer-check CloudFront Function to the default cache behavior. Set to false to reuse this module without referer gating."
  default     = true
}

variable "default_root_object" {
  type        = string
  description = "Object returned for requests to the distribution's root URL (e.g. \"index.html\"). Empty string disables it."
  default     = ""
}

variable "min_ttl" {
  type        = number
  description = "Minimum time, in seconds, that objects stay in the CloudFront cache before origin revalidation."
  default     = 0
}

variable "default_ttl" {
  type        = number
  description = "Default time, in seconds, that objects stay in the CloudFront cache when the origin sends no explicit cache-control headers."
  default     = 86400
}

variable "max_ttl" {
  type        = number
  description = "Maximum time, in seconds, that objects stay in the CloudFront cache regardless of origin cache-control headers."
  default     = 31536000
}

variable "price_class" {
  type        = string
  description = "CloudFront price class."
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources in this module."
  default     = {}
}
