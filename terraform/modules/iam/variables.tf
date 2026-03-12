variable "project_name" { type = string }
variable "environment" { type = string }
variable "eks_oidc_provider_arn" { type = string }
variable "eks_oidc_provider_url" { type = string }
variable "rds_resource_arn" { type = string }
variable "s3_bucket_arns" { type = list(string) }
