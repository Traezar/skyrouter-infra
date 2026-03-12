output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "frontend_iam_role_arn" {
  value = module.iam.frontend_role_arn
}

output "backend_iam_role_arn" {
  value = module.iam.backend_role_arn
}

output "ecr_frontend_url" {
  value = module.eks.ecr_frontend_url
}

output "ecr_backend_url" {
  value = module.eks.ecr_backend_url
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
