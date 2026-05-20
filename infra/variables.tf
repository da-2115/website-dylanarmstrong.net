// variables.tf
// Dylan Armstrong, 2026

variable "aws_region" {
  description = "AWS region for pipeline and build resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Base name used for AWS resources"
  type        = string
  default     = "website-dylanarmstrong"
}

variable "github_full_repository" {
  description = "GitHub repository in owner/repo format"
  type        = string
  default     = "da-2115/website-dylanarmstrong.net"
}

variable "github_branch" {
  description = "Git branch that triggers the pipeline"
  type        = string
  default     = "main"
}

variable "codeconnections_connection_arn" {
  description = "AWS CodeConnections connection ARN used by CodePipeline source stage"
  type        = string
  default     = null
}

variable "codestar_connection_arn" {
  description = "Deprecated alias for codeconnections_connection_arn (kept for backward compatibility)"
  type        = string
  default     = null
}

variable "deploy_bucket_name" {
  description = "Optional S3 bucket name where the built static site is deployed"
  type        = string
  default     = null
}

variable "create_deploy_bucket" {
  description = "When true, Terraform creates and manages the deploy bucket"
  type        = bool
  default     = true
}

variable "website_directory" {
  description = "Repository subdirectory containing the Vue project"
  type        = string
  default     = "website"
}

variable "build_output_directory" {
  description = "Build output directory inside the Vue project"
  type        = string
  default     = "dist"
}

variable "cloudfront_distribution_id" {
  description = "Optional existing CloudFront distribution ID used when create_cloudfront_distribution is false"
  type        = string
  default     = null
}

variable "create_cloudfront_distribution" {
  description = "When true, Terraform creates and manages a CloudFront distribution for the deploy bucket"
  type        = bool
  default     = true
}

variable "primary_domain_name" {
  description = "Primary custom domain served by CloudFront"
  type        = string
  default     = "dylanarmstrong.net"
}

variable "www_domain_name" {
  description = "WWW subdomain served by CloudFront"
  type        = string
  default     = "www.dylanarmstrong.net"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID used for ACM validation and alias records"
  type        = string
  default     = null

  validation {
    condition     = !var.create_cloudfront_distribution || var.route53_zone_id != null
    error_message = "route53_zone_id is required when create_cloudfront_distribution is true."
  }
}

variable "tags" {
  description = "Additional tags to apply to created resources"
  type        = map(string)
  default     = {}
}
