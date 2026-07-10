include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/00-network.hcl"
  merge_strategy = "deep"
  expose         = true
}

inputs = {
  cluster_name         = "saas-eks-test"
  vpc_cidr             = "10.0.0.0/16"
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.5.0/24"]
  private_subnets      = ["10.0.3.0/24", "10.0.4.0/24", "10.0.6.0/24"]
  schema_registry_name = "saas-schema-registry"
}
