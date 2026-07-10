package terraform.governance

rc(type, after) := {
	"address": sprintf("%s.example", [type]),
	"type": type,
	"change": {"actions": ["create"], "after": after, "after_unknown": {}},
}

plan(rcs, env) := {"resource_changes": rcs, "variables": {"environment": {"value": env}}}

test_prod_rds_without_deletion_protection_warns if {
	some msg in warn with input as plan([rc("aws_db_instance", {"deletion_protection": false, "multi_az": true})], "prod")
	contains(msg, "deletion_protection")
}

test_prod_rds_not_multi_az_warns if {
	some msg in warn with input as plan([rc("aws_db_instance", {"deletion_protection": true, "multi_az": false})], "prod")
	contains(msg, "not Multi-AZ")
}

test_dev_rds_no_warn if {
	count(warn) == 0 with input as plan([rc("aws_db_instance", {"deletion_protection": false, "multi_az": false})], "dev")
}

test_skip_final_snapshot_warns_in_prod if {
	some msg in warn with input as plan([rc("aws_db_instance", {"deletion_protection": true, "multi_az": true, "skip_final_snapshot": true})], "prod")
	contains(msg, "skip_final_snapshot")
}

test_missing_tag_warns if {
	after := {"deletion_protection": true, "multi_az": true, "tags": {"Environment": "prod", "ManagedBy": "terraform"}}
	some msg in warn with input as plan([rc("aws_db_instance", after)], "prod")
	contains(msg, "Project")
}

test_complete_tags_no_tag_warn if {
	after := {"deletion_protection": true, "multi_az": true, "tags": {"Environment": "prod", "ManagedBy": "terraform", "Project": "saas"}}
	count([m | some m in warn; contains(m, "required tag")]) == 0 with input as plan([rc("aws_db_instance", after)], "prod")
}
