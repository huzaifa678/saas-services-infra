output "key_arn" {
  description = "ARN of the CMK, for encryption_configuration / kms_key_arn inputs."
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "Key ID of the CMK."
  value       = aws_kms_key.this.key_id
}

output "alias_arn" {
  description = "ARN of the key alias."
  value       = aws_kms_alias.this.arn
}

output "alias_name" {
  description = "The alias name."
  value       = aws_kms_alias.this.name
}
