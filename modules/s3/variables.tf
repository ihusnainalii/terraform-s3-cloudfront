variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket to create."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."

  validation {
    condition     = contains(["develop", "staging", "production"], var.environment)
    error_message = "environment must be one of: develop, staging, production."
  }
}

variable "kms_deletion_window" {
  type        = number
  description = "Waiting period, in days, before the KMS key is deleted after being scheduled for deletion."
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "kms_deletion_window must be between 7 and 30 days."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources in this module."
  default     = {}
}
