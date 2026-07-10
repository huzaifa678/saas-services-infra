package main

import rego.v1

required_tags := {"Environment", "ManagedBy"}

taggable := {
	"aws_db_instance",
	"aws_ecr_repository",
	"aws_security_group",
	"aws_kms_key",
	"aws_s3_bucket",
	"aws_eks_cluster",
	"aws_elasticache_cluster",
	"aws_msk_cluster",
}

warn contains msg if {
	some kind in taggable
	some rc in tf_resources(kind)
	tags := object.get(after(rc), "tags", {})
	some t in required_tags
	not tags[t]
	msg := sprintf("%s %q is missing recommended tag %q", [rc.type, rc.address, t])
}

warn contains msg if {
	some rc in tf_resources("aws_db_instance")
	after(rc).skip_final_snapshot == true
	msg := sprintf("RDS instance %q has skip_final_snapshot=true — a final snapshot is recommended outside of test", [rc.address])
}

warn contains msg if {
	some rc in tf_resources("aws_db_instance")
	after(rc).deletion_protection != true
	msg := sprintf("RDS instance %q should set deletion_protection=true", [rc.address])
}

warn contains msg if {
	some rc in tf_resources("aws_security_group")
	some ingress in object.get(after(rc), "ingress", [])
	opens_world(ingress.cidr_blocks)
	msg := sprintf("Security group %q allows ingress from 0.0.0.0/0 on %d-%d — confirm this is intentional", [rc.address, ingress.from_port, ingress.to_port])
}
