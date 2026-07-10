package terraform.security

# Each test synthesises the slice of `terraform show -json` the rule reads. No AWS
# and no real plan required, so these run in CI on every push.

rc(type, after) := {
	"address": sprintf("%s.example", [type]),
	"type": type,
	"change": {"actions": ["create"], "after": after, "after_unknown": {}},
}

plan(rcs) := {"resource_changes": rcs, "variables": {"environment": {"value": "prod"}}}

test_public_rds_denied if {
	some msg in deny with input as plan([rc("aws_db_instance", {"publicly_accessible": true, "storage_encrypted": true})])
	contains(msg, "publicly accessible")
}

test_private_encrypted_rds_allowed if {
	count(deny) == 0 with input as plan([rc("aws_db_instance", {"publicly_accessible": false, "storage_encrypted": true})])
}

test_unencrypted_rds_denied if {
	some msg in deny with input as plan([rc("aws_db_instance", {"publicly_accessible": false, "storage_encrypted": false})])
	contains(msg, "not encrypted")
}

test_unauthenticated_msk_denied if {
	after := {"client_authentication": [{"unauthenticated": true}], "encryption_info": [{"encryption_in_transit": [{"client_broker": "TLS"}]}]}
	some msg in deny with input as plan([rc("aws_msk_cluster", after)])
	contains(msg, "unauthenticated")
}

test_authenticated_tls_msk_allowed if {
	after := {"client_authentication": [{"unauthenticated": false}], "encryption_info": [{"encryption_in_transit": [{"client_broker": "TLS"}]}]}
	count(deny) == 0 with input as plan([rc("aws_msk_cluster", after)])
}

test_plaintext_msk_denied if {
	after := {"client_authentication": [{"unauthenticated": false}], "encryption_info": [{"encryption_in_transit": [{"client_broker": "PLAINTEXT"}]}]}
	some msg in deny with input as plan([rc("aws_msk_cluster", after)])
	contains(msg, "must be TLS")
}

test_plaintext_redis_denied if {
	some msg in deny with input as plan([rc("aws_elasticache_replication_group", {"transit_encryption_enabled": false, "at_rest_encryption_enabled": true})])
	contains(msg, "transit encryption")
}

test_encrypted_redis_allowed if {
	count(deny) == 0 with input as plan([rc("aws_elasticache_replication_group", {"transit_encryption_enabled": true, "at_rest_encryption_enabled": true})])
}

test_mutable_ecr_denied if {
	some msg in deny with input as plan([rc("aws_ecr_repository", {"image_tag_mutability": "MUTABLE"})])
	contains(msg, "mutable")
}

test_immutable_ecr_allowed if {
	count(deny) == 0 with input as plan([rc("aws_ecr_repository", {"image_tag_mutability": "IMMUTABLE"})])
}

test_world_open_ingress_denied if {
	after := {"cidr_ipv4": "0.0.0.0/0", "from_port": 443, "tags": {"Name": "saas-eks-prod-rds-sg"}}
	some msg in deny with input as plan([rc("aws_vpc_security_group_ingress_rule", after)])
	contains(msg, "0.0.0.0/0")
}

test_ava_endpoint_world_open_exempt if {
	after := {"cidr_ipv4": "0.0.0.0/0", "from_port": 443, "tags": {"Name": "saas-eks-prod-ava-endpoint-sg"}}
	count(deny) == 0 with input as plan([rc("aws_vpc_security_group_ingress_rule", after)])
}

test_iam_star_star_denied if {
	policy := json.marshal({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "*", "Resource": "*"}]})
	some msg in deny with input as plan([rc("aws_iam_role_policy", {"policy": policy})])
	contains(msg, "Action:* on Resource:*")
}

test_scoped_iam_allowed if {
	policy := json.marshal({"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": ["arn:aws:s3:::b/*"]}]})
	count(deny) == 0 with input as plan([rc("aws_iam_role_policy", {"policy": policy})])
}
