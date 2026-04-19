plugin "aws" {
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  version = "0.38.0"
  enabled = true

  deep_check = true
}

config {
  call_module_type = "all"
}

# Terraform core rules only

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}