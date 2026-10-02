terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

# Persistent self-hosted GitHub Actions runner inside the VPC. This is the
# standing CI executor: terragrunt plan/apply for the private-endpoint layers run
# here (runs-on: [self-hosted, vpc]), because an in-VPC host is the only way to
# reach the private EKS API without a VPN — humans use AWS Verified Access, the
# runner uses VPC networking, and the two paths are independent.
#
# Only the runner's CREATION is a one-time manual step; it then runs forever.
# Least privilege: the instance profile below holds NO deploy rights — jobs
# federate GitHub OIDC into the scoped roles from modules/gha-oidc. The host can
# only read its registration secret and pull the toolchain image from ECR.

data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# PAT for runner registration. Created empty — seed the value out-of-band so no
# credential is committed:
#   aws secretsmanager put-secret-value --secret-id <arn> --secret-string <pat>
# Needs the repo's manage-runners scope; rotated manually (GitHub PATs have no
# Secrets Manager rotation hook).
resource "aws_secretsmanager_secret" "runner_pat" {
  # checkov:skip=CKV2_AWS_57:GitHub PATs have no Secrets Manager rotation hook; rotated manually out-of-band.
  name                    = "${var.name}-gha-runner-pat"
  description             = "GitHub PAT the self-hosted runner uses to fetch a registration token."
  kms_key_id              = var.kms_key_arn != "" ? var.kms_key_arn : null
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

# --- IAM: a deliberately thin instance profile. No AWS deploy creds live on the
# host (that is OIDC's job); this only reads the PAT, pulls the ECR image, and
# enables SSM management. ---
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "${var.name}-gha-runner"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "host" {
  statement {
    sid       = "ReadRunnerPat"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.runner_pat.arn]
  }
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid    = "EcrPullToolchain"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "host" {
  name   = "${var.name}-gha-runner-host"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.host.json
}

resource "aws_iam_instance_profile" "runner" {
  name = "${var.name}-gha-runner"
  role = aws_iam_role.runner.name
}

resource "aws_security_group" "runner" {
  name        = "${var.name}-gha-runner"
  description = "Self-hosted GHA runner - egress only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-gha-runner" })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.runner.id
  description       = "All egress (GitHub, STS, ECR, EKS API)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_launch_template" "runner" {
  name_prefix   = "${var.name}-gha-runner-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.runner.arn
  }

  vpc_security_group_ids = [aws_security_group.runner.id]

  # IMDSv2 only (blocks SSRF credential theft); hop_limit 2 so the containerized
  # job can still reach IMDS for the instance role.
  # checkov:skip=CKV_AWS_341:hop_limit 2 lets the containerized job reach IMDS; IMDSv2 is enforced via http_tokens=required.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn != "" ? var.kms_key_arn : null
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    region         = data.aws_region.current.region
    pat_secret_arn = aws_secretsmanager_secret.runner_pat.arn
    github_owner   = var.github_owner
    github_repo    = var.github_repo
    runner_labels  = var.runner_labels
    runner_name    = "${var.name}-vpc"
    runner_version = var.runner_version
    ecr_registry   = var.ecr_registry
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-gha-runner" })
  }
}

resource "aws_autoscaling_group" "runner" {
  name                = "${var.name}-gha-runner"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.runner.id
    version = "$Latest"
  }

  # Replace the instance when the launch template (e.g. user-data, toolchain
  # image tag) changes, so re-registration is a `terraform apply` away.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-gha-runner"
    propagate_at_launch = true
  }
}
