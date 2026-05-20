#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WEBSITE_DIR="${WEBSITE_DIR:-website}"
BUILD_DIR="${BUILD_DIR:-dist}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
DEPLOY_BUCKET="${DEPLOY_BUCKET:-${S3_BUCKET:-}}"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"
SKIP_BUILD="false"
SKIP_TERRAFORM="false"
SKIP_DEPLOY="false"
TERRAFORM_DIR="${TERRAFORM_DIR:-infra}"
TERRAFORM_AUTO_APPROVE="true"
DRY_RUN="false"
CODECONNECTIONS_CONNECTION_ARN="${CODECONNECTIONS_CONNECTION_ARN:-${CODESTAR_CONNECTION_ARN:-}}"
TERRAFORM_DEPLOY_ONLY="${TERRAFORM_DEPLOY_ONLY:-false}"
TF_VAR_FILES=()
TF_EXTRA_ARGS=()

usage() {
  cat <<EOF
Usage: ./deploy.sh [options]

Run Terraform, build a static website, and deploy it to S3.

Options:
  --bucket <name>            S3 bucket name (optional if Terraform output is available)
  --region <region>          AWS region (default: ap-southeast-2)
  --codeconnections-connection-arn <arn>
                              AWS CodeConnections ARN for full pipeline terraform apply
  --codestar-connection-arn <arn>
                              Deprecated alias for --codeconnections-connection-arn
  --terraform-deploy-only    Apply only deploy-bucket resources (skips pipeline resources)
  --terraform-dir <path>     Terraform directory relative to repo root (default: infra)
  --tf-var-file <path>       Terraform var-file (repeatable)
  --tf-arg <arg>             Extra argument passed to terraform apply/plan (repeatable)
  --no-auto-approve          Run terraform apply without -auto-approve
  --website-dir <path>       Website directory relative to repo root (default: website)
  --build-dir <path>         Build output directory inside website dir (default: dist)
  --distribution-id <id>     Optional CloudFront distribution ID for invalidation
  --skip-terraform           Skip terraform init/apply
  --skip-build               Skip dependency install and build steps
  --skip-deploy              Skip AWS sync/invalidation phase
  --dry-run                  Show actions without mutating AWS resources
  -h, --help                 Show this help message

Environment variables:
  DEPLOY_BUCKET, S3_BUCKET, AWS_REGION, WEBSITE_DIR, BUILD_DIR,
  CLOUDFRONT_DISTRIBUTION_ID, TERRAFORM_DIR, CODECONNECTIONS_CONNECTION_ARN,
  CODESTAR_CONNECTION_ARN,
  TERRAFORM_DEPLOY_ONLY, SKIP_BUILD, DRY_RUN
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Error: ${cmd} is required." >&2
    exit 1
  fi
}

resolve_bucket_from_terraform() {
  local tf_dir="${ROOT_DIR}/${TERRAFORM_DIR}"
  if [[ ! -d "${tf_dir}" ]]; then
    return 1
  fi

  require_command terraform

  terraform -chdir="${tf_dir}" output -raw deploy_bucket_name 2>/dev/null || return 1
}

run_terraform() {
  local tf_dir="${ROOT_DIR}/${TERRAFORM_DIR}"
  local tf_args=("-input=false")
  local tf_apply_args=()
  local tf_plan_args=()

  if [[ ! -d "${tf_dir}" ]]; then
    echo "Error: terraform directory not found: ${tf_dir}" >&2
    exit 1
  fi

  require_command terraform

  tf_args+=("-var" "aws_region=${AWS_REGION}")
  tf_args+=("-var" "website_directory=${WEBSITE_DIR}")
  tf_args+=("-var" "build_output_directory=${BUILD_DIR}")

  if [[ "${TERRAFORM_DEPLOY_ONLY}" == "true" ]]; then
    tf_args+=("-var" "codeconnections_connection_arn=arn:aws:codestar-connections:${AWS_REGION}:000000000000:connection/placeholder")
    tf_args+=("-target=aws_s3_bucket.deploy_bucket")
    tf_args+=("-target=aws_s3_bucket_versioning.deploy_bucket")
    tf_args+=("-target=aws_s3_bucket_public_access_block.deploy_bucket")
    tf_args+=("-target=aws_s3_bucket_policy.deploy_bucket_cloudfront_read")
    tf_args+=("-target=aws_cloudfront_origin_access_control.website")
    tf_args+=("-target=aws_cloudfront_distribution.website")
  elif [[ -n "${CODECONNECTIONS_CONNECTION_ARN}" ]]; then
    tf_args+=("-var" "codeconnections_connection_arn=${CODECONNECTIONS_CONNECTION_ARN}")
  else
    echo "Error: CODECONNECTIONS_CONNECTION_ARN is required for full Terraform apply." >&2
    echo "Set --codeconnections-connection-arn (or CODECONNECTIONS_CONNECTION_ARN), or use --terraform-deploy-only." >&2
    exit 1
  fi

  for tf_var_file in "${TF_VAR_FILES[@]:-}"; do
    [[ -n "${tf_var_file}" ]] || continue
    tf_args+=("-var-file" "${tf_var_file}")
  done

  for tf_extra_arg in "${TF_EXTRA_ARGS[@]:-}"; do
    [[ -n "${tf_extra_arg}" ]] || continue
    tf_args+=("${tf_extra_arg}")
  done

  echo "Initializing Terraform in ${tf_dir}"
  terraform -chdir="${tf_dir}" init

  if [[ "${DRY_RUN}" == "true" ]]; then
    tf_plan_args=("${tf_args[@]}")
    if [[ "${TERRAFORM_DEPLOY_ONLY}" == "true" ]]; then
      echo "Running terraform plan for deploy resources only (dry run)"
    elif [[ -n "${CODECONNECTIONS_CONNECTION_ARN}" ]]; then
      echo "Running terraform plan (dry run)"
    else
      echo "Running terraform plan (dry run)"
    fi
    terraform -chdir="${tf_dir}" plan "${tf_plan_args[@]}"
    return
  fi

  tf_apply_args=("${tf_args[@]}")
  if [[ "${TERRAFORM_AUTO_APPROVE}" == "true" ]]; then
    tf_apply_args+=("-auto-approve")
  fi

  if [[ "${TERRAFORM_DEPLOY_ONLY}" == "true" ]]; then
    echo "Applying Terraform for deploy resources only"
  elif [[ -n "${CODECONNECTIONS_CONNECTION_ARN}" ]]; then
    echo "Applying full Terraform configuration"
  else
    echo "Applying full Terraform configuration"
  fi
  terraform -chdir="${tf_dir}" apply "${tf_apply_args[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      DEPLOY_BUCKET="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --codeconnections-connection-arn)
      CODECONNECTIONS_CONNECTION_ARN="$2"
      shift 2
      ;;
    --codestar-connection-arn)
      CODECONNECTIONS_CONNECTION_ARN="$2"
      shift 2
      ;;
    --terraform-deploy-only)
      TERRAFORM_DEPLOY_ONLY="true"
      shift
      ;;
    --terraform-dir)
      TERRAFORM_DIR="$2"
      shift 2
      ;;
    --tf-var-file)
      TF_VAR_FILES+=("$2")
      shift 2
      ;;
    --tf-arg)
      TF_EXTRA_ARGS+=("$2")
      shift 2
      ;;
    --no-auto-approve)
      TERRAFORM_AUTO_APPROVE="false"
      shift
      ;;
    --website-dir)
      WEBSITE_DIR="$2"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    --distribution-id)
      CLOUDFRONT_DISTRIBUTION_ID="$2"
      shift 2
      ;;
    --skip-terraform)
      SKIP_TERRAFORM="true"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    --skip-deploy)
      SKIP_DEPLOY="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${SKIP_TERRAFORM}" != "true" ]]; then
  run_terraform
else
  echo "Skipping Terraform (--skip-terraform)"
fi

SITE_PATH="${ROOT_DIR}/${WEBSITE_DIR}"
OUTPUT_PATH="${SITE_PATH}/${BUILD_DIR}"

if [[ ! -d "${SITE_PATH}" ]]; then
  echo "Error: website directory not found: ${SITE_PATH}" >&2
  exit 1
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
  require_command npm

  echo "Installing dependencies in ${SITE_PATH}"
  pushd "${SITE_PATH}" >/dev/null
  if [[ -f package-lock.json ]]; then
    npm ci
  elif [[ -f yarn.lock ]]; then
    corepack enable
    yarn install --frozen-lockfile
  elif [[ -f pnpm-lock.yaml ]]; then
    corepack enable
    pnpm install --frozen-lockfile
  else
    npm install
  fi

  echo "Building site"
  if [[ -f package-lock.json ]]; then
    npm run build
  elif [[ -f yarn.lock ]]; then
    yarn build
  elif [[ -f pnpm-lock.yaml ]]; then
    pnpm build
  else
    npm run build
  fi
  popd >/dev/null
else
  echo "Skipping build (--skip-build)"
fi

if [[ "${SKIP_DEPLOY}" != "true" ]]; then
  require_command aws

  if [[ -z "${DEPLOY_BUCKET}" ]]; then
    if DEPLOY_BUCKET="$(resolve_bucket_from_terraform)"; then
      echo "Resolved deploy bucket from Terraform output: ${DEPLOY_BUCKET}"
    else
      echo "Error: DEPLOY_BUCKET is required (set --bucket, DEPLOY_BUCKET, S3_BUCKET, or expose deploy_bucket_name output)." >&2
      exit 1
    fi
  fi

  if [[ ! -d "${OUTPUT_PATH}" ]]; then
    echo "Error: build output directory not found: ${OUTPUT_PATH}" >&2
    exit 1
  fi

  echo "Deploying ${OUTPUT_PATH} to s3://${DEPLOY_BUCKET} in ${AWS_REGION}"
  AWS_S3_ARGS=(--region "${AWS_REGION}" s3 sync "${OUTPUT_PATH}" "s3://${DEPLOY_BUCKET}" --delete)
  if [[ "${DRY_RUN}" == "true" ]]; then
    AWS_S3_ARGS+=(--dryrun)
  fi
  aws "${AWS_S3_ARGS[@]}"

  if [[ -n "${CLOUDFRONT_DISTRIBUTION_ID}" ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "Dry run enabled: skipping CloudFront invalidation for ${CLOUDFRONT_DISTRIBUTION_ID}"
    else
      echo "Creating CloudFront invalidation for ${CLOUDFRONT_DISTRIBUTION_ID}"
      aws --region "${AWS_REGION}" cloudfront create-invalidation \
        --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" \
        --paths "/*" >/dev/null
    fi
  fi
else
  echo "Skipping deploy (--skip-deploy)"
fi

echo "Deploy complete"
