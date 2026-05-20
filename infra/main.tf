// main.tf
// Dylan Armstrong, 2026

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  artifact_bucket_name                 = "${substr(var.project_name, 0, 18)}-pa-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  deploy_bucket_name                   = coalesce(var.deploy_bucket_name, "${var.project_name}-site-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}")
  effective_connection_arn             = coalesce(var.codeconnections_connection_arn, var.codestar_connection_arn, "arn:aws:codestar-connections:${var.aws_region}:000000000000:connection/placeholder")
  deploy_bucket_regional_domain_name   = var.create_deploy_bucket ? aws_s3_bucket.deploy_bucket[0].bucket_regional_domain_name : data.aws_s3_bucket.deploy_bucket_existing[0].bucket_regional_domain_name
  effective_cloudfront_distribution_id = try(aws_cloudfront_distribution.website[0].id, coalesce(var.cloudfront_distribution_id, ""))
  common_tags = merge(
    {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "production"
    },
    var.tags
  )
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = local.artifact_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket" "deploy_bucket" {
  count  = var.create_deploy_bucket ? 1 : 0
  bucket = local.deploy_bucket_name
  tags   = local.common_tags
}

data "aws_s3_bucket" "deploy_bucket_existing" {
  count  = var.create_deploy_bucket ? 0 : 1
  bucket = local.deploy_bucket_name
}

resource "aws_s3_bucket_versioning" "deploy_bucket" {
  count  = var.create_deploy_bucket ? 1 : 0
  bucket = aws_s3_bucket.deploy_bucket[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "deploy_bucket" {
  count                   = var.create_deploy_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.deploy_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "website" {
  count                             = var.create_cloudfront_distribution ? 1 : 0
  name                              = "${var.project_name}-oac"
  description                       = "OAC for ${local.deploy_bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  count               = var.create_cloudfront_distribution ? 1 : 0
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} website"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = local.deploy_bucket_regional_domain_name
    origin_id                = "s3-${local.deploy_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website[0].id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-${local.deploy_bucket_name}"
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "deploy_bucket_cloudfront_read" {
  count = var.create_cloudfront_distribution ? 1 : 0

  statement {
    sid    = "AllowCloudFrontServiceRead"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.deploy_bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "deploy_bucket_cloudfront_read" {
  count  = var.create_cloudfront_distribution ? 1 : 0
  bucket = local.deploy_bucket_name
  policy = data.aws_iam_policy_document.deploy_bucket_cloudfront_read[0].json
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid    = "CodeBuildLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ArtifactBucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*"
    ]
  }

  statement {
    sid    = "DeployBucketSync"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.deploy_bucket_name}",
      "arn:aws:s3:::${local.deploy_bucket_name}/*"
    ]
  }

  statement {
    sid       = "CloudFrontInvalidation"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${var.project_name}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

data "aws_iam_policy_document" "codepipeline_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.project_name}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    sid    = "ArtifactBucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.pipeline_artifacts.arn,
      "${aws_s3_bucket.pipeline_artifacts.arn}/*"
    ]
  }

  statement {
    sid    = "CodeBuildAccess"
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [aws_codebuild_project.website_build.arn]
  }

  statement {
    sid    = "UseCodeStarConnection"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
      "codeconnections:UseConnection"
    ]
    resources = [local.effective_connection_arn]
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${var.project_name}-codepipeline-policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

// CodeBuild
resource "aws_codebuild_project" "website_build" {
  name         = "${var.project_name}-build-deploy"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "DEPLOY_BUCKET"
      value = local.deploy_bucket_name
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "WEBSITE_DIR"
      value = var.website_directory
    }

    environment_variable {
      name  = "BUILD_DIR"
      value = var.build_output_directory
    }

    environment_variable {
      name  = "CLOUDFRONT_DISTRIBUTION_ID"
      value = local.effective_cloudfront_distribution_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.codebuild.yml"
  }

  tags = local.common_tags
}

// CodePipeline
resource "aws_codepipeline" "website_pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn    = local.effective_connection_arn
        FullRepositoryId = var.github_full_repository
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "BuildAndDeploy"

    action {
      name             = "BuildAndDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.website_build.name
      }
    }
  }

  tags = local.common_tags
}

