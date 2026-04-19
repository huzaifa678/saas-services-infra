resource "aws_kms_key" "main" {
  description             = "Shared KMS key for ${var.cluster_name} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = { Name = "${var.cluster_name}-kms" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.cluster_name}"
  target_key_id = aws_kms_key.main.key_id
}
