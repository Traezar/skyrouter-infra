locals {
  prefix = "${var.project_name}-${var.environment}"
}

# =============================================================================
# IRSA (IAM Roles for Service Accounts)
#
# This is how AWS IAM authentication works in EKS:
# 1. EKS has an OIDC provider
# 2. Kubernetes ServiceAccounts are annotated with an IAM role ARN
# 3. Pods using that ServiceAccount get temporary AWS credentials injected
# 4. The trust policy restricts which namespace:serviceaccount can assume the role
# =============================================================================

# ---------- Backend IRSA Role ----------
# The backend needs: RDS IAM auth, Secrets Manager, S3, CloudWatch
resource "aws_iam_role" "backend" {
  name = "${local.prefix}-backend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:default:backend-sa"
        }
      }
    }]
  })
}

# Allow backend to authenticate to RDS via IAM
resource "aws_iam_role_policy" "backend_rds" {
  name = "${local.prefix}-backend-rds"
  role = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = var.rds_resource_arn
    }]
  })
}

# Allow backend to read database credentials from Secrets Manager
resource "aws_iam_role_policy" "backend_secrets" {
  name = "${local.prefix}-backend-secrets"
  role = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:${local.prefix}-*"
    }]
  })
}

# Allow backend to push metrics/logs to CloudWatch
resource "aws_iam_role_policy" "backend_cloudwatch" {
  name = "${local.prefix}-backend-cloudwatch"
  role = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData"
      ]
      Resource = "*"
    }]
  })
}

# Allow backend S3 access (if any buckets configured)
resource "aws_iam_role_policy" "backend_s3" {
  count = length(var.s3_bucket_arns) > 0 ? 1 : 0
  name  = "${local.prefix}-backend-s3"
  role  = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ]
      Resource = concat(
        var.s3_bucket_arns,
        [for arn in var.s3_bucket_arns : "${arn}/*"]
      )
    }]
  })
}

# ---------- Frontend IRSA Role ----------
# Frontend is mostly static, but may need CloudWatch + limited S3 for assets
resource "aws_iam_role" "frontend" {
  name = "${local.prefix}-frontend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:default:frontend-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "frontend_cloudwatch" {
  name = "${local.prefix}-frontend-cloudwatch"
  role = aws_iam_role.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# ---------- ALB Ingress Controller IRSA Role ----------
resource "aws_iam_role" "alb_controller" {
  name = "${local.prefix}-alb-controller-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Full ALB controller policy (AWS provides this)
resource "aws_iam_role_policy" "alb_controller" {
  name = "${local.prefix}-alb-controller"
  role = aws_iam_role.alb_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "elasticloadbalancing:*",
          "iam:CreateServiceLinkedRole",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "waf-regional:*",
          "wafv2:*",
          "shield:*",
          "tag:GetResources",
          "tag:TagResources"
        ]
        Resource = "*"
      }
    ]
  })
}
