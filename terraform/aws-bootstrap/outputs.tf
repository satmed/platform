output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "region" {
  value = var.region
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}
