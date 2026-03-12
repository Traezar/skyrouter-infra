output "backend_role_arn" {
  value = aws_iam_role.backend.arn
}

output "frontend_role_arn" {
  value = aws_iam_role.frontend.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}
