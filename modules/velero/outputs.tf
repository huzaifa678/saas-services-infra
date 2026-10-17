output "bucket_name" {
  description = "S3 bucket Velero writes backups to."
  value       = aws_s3_bucket.this.bucket
}

output "role_arn" {
  description = "IAM role the Velero pod assumes via EKS Pod Identity."
  value       = aws_iam_role.this.arn
}
