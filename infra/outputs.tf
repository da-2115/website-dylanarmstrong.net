// outputs.tf
// Dylan Armstrong, 2026

output "pipeline_name" {
  description = "Name of the created CodePipeline"
  value       = aws_codepipeline.website_pipeline.name
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project used by the pipeline"
  value       = aws_codebuild_project.website_build.name
}

output "pipeline_artifact_bucket" {
  description = "Artifact bucket used by CodePipeline"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "deploy_bucket_name" {
  description = "S3 bucket used for website deployment"
  value       = local.deploy_bucket_name
}

output "deploy_bucket_managed_by_terraform" {
  description = "Whether Terraform manages the deploy bucket resource"
  value       = var.create_deploy_bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for deployment invalidations"
  value       = local.effective_cloudfront_distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the Terraform-managed CloudFront distribution"
  value       = try(aws_cloudfront_distribution.website[0].domain_name, null)
}

output "website_primary_domain_name" {
  description = "Primary custom domain served by CloudFront"
  value       = var.primary_domain_name
}

output "website_www_domain_name" {
  description = "WWW custom domain served by CloudFront"
  value       = var.www_domain_name
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN used by CloudFront"
  value       = try(aws_acm_certificate_validation.website[0].certificate_arn, null)
}
