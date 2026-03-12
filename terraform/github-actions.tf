locals {
  github_repo = "Traezar/skyrouter"
  prefix      = "${var.project_name}-${var.environment}"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${local.prefix}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${local.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${local.prefix}-github-actions-ecr"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${var.environment}-backend"
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_eks" {
  name = "${local.prefix}-github-actions-eks"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "eks:DescribeCluster"
      Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-${var.environment}-cluster"
    }]
  })
}

resource "null_resource" "eks_github_actions_access" {
  triggers = {
    role_arn     = aws_iam_role.github_actions_deploy.arn
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-cluster-config \
        --name ${module.eks.cluster_name} \
        --region ${var.aws_region} \
        --access-config authenticationMode=API_AND_CONFIG_MAP \
        --no-cli-pager 2>/dev/null || true

      aws eks wait cluster-active \
        --name ${module.eks.cluster_name} \
        --region ${var.aws_region}

      aws eks create-access-entry \
        --cluster-name ${module.eks.cluster_name} \
        --region ${var.aws_region} \
        --principal-arn ${aws_iam_role.github_actions_deploy.arn} \
        --type STANDARD \
        --no-cli-pager 2>/dev/null || true

      aws eks associate-access-policy \
        --cluster-name ${module.eks.cluster_name} \
        --region ${var.aws_region} \
        --principal-arn ${aws_iam_role.github_actions_deploy.arn} \
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
        --access-scope type=cluster \
        --no-cli-pager
    EOT
  }
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deploy.arn
  description = "IAM role ARN for GitHub Actions deployments"
}
