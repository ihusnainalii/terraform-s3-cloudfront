variable "domain_name" {
  type        = string
  description = "Fully-qualified domain name the certificate is issued for."
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names to include on the certificate."
  default     = []
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID used for DNS validation."
}

variable "environment" {
  type        = string
  description = "Deployment environment name, used for the Environment tag."

  validation {
    condition     = contains(["develop", "staging", "production"], var.environment)
    error_message = "environment must be one of: develop, staging, production."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources in this module."
  default     = {}
}
