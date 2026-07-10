package main

import rego.v1

_plan(resources) := {"resource_changes": resources}

_rds(after) := {
	"address": "module.rds.aws_db_instance.this",
	"type": "aws_db_instance",
	"mode": "managed",
	"change": {"actions": ["create"], "after": after},
}


test_deny_public_rds if {
	count(deny) > 0 with input as _plan([_rds({
		"publicly_accessible": true,
		"storage_encrypted": true,
	})])
}

test_allow_private_encrypted_rds if {
	count(deny) == 0 with input as _plan([_rds({
		"publicly_accessible": false,
		"storage_encrypted": true,
		"deletion_protection": true,
		"skip_final_snapshot": false,
	})])
}


test_deny_unencrypted_rds if {
	count(deny) > 0 with input as _plan([_rds({"storage_encrypted": false})])
}


test_deny_world_open_ssh if {
	count(deny) > 0 with input as _plan([{
		"address": "aws_security_group_rule.bad",
		"type": "aws_security_group_rule",
		"mode": "managed",
		"change": {"actions": ["create"], "after": {
			"type": "ingress",
			"from_port": 22,
			"to_port": 22,
			"cidr_blocks": ["0.0.0.0/0"],
		}},
	}])
}

test_allow_world_open_https if {
	count(deny) == 0 with input as _plan([{
		"address": "aws_security_group.ava",
		"type": "aws_security_group",
		"mode": "managed",
		"change": {"actions": ["create"], "after": {"ingress": [{
			"from_port": 443,
			"to_port": 443,
			"cidr_blocks": ["0.0.0.0/0"],
		}]}},
	}])
}


test_deny_iam_star_star if {
	count(deny) > 0 with input as _plan([{
		"address": "aws_iam_policy.admin",
		"type": "aws_iam_policy",
		"mode": "managed",
		"change": {"actions": ["create"], "after": {"policy": json.marshal({"Statement": [{
			"Effect": "Allow",
			"Action": "*",
			"Resource": "*",
		}]})}},
	}])
}


test_warn_missing_tags if {
	count(warn) > 0 with input as _plan([_rds({
		"publicly_accessible": false,
		"storage_encrypted": true,
		"tags": {"Name": "x"},
	})])
}
