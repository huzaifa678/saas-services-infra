package terraform.security

# Blocking controls. Every rule here is an unambiguous defect, so it hard-fails
# the plan. Advisory checks live in governance.rego.
#
# These deliberately overlap the Checkov custom checks and the module-level
# preconditions: one tool failing open must not let an insecure plan reach AWS.

import data.lib.tfplan

world := {"0.0.0.0/0"}

world_v6 := {"::/0", "0000:0000:0000:0000:0000:0000:0000:0000/0"}

# Ports that must never be reachable from the whole internet.
admin_ports := {22, 3389, 5432, 3306, 6379, 27017, 9092, 9094, 9096, 9098, 2379, 10250}

# --- RDS --------------------------------------------------------------------

deny contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	rc.change.after.publicly_accessible == true
	msg := sprintf("%s: RDS instance is publicly accessible.", [tfplan.addr(rc)])
}

deny contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	tfplan.not_true(rc, "storage_encrypted")
	msg := sprintf("%s: RDS storage is not encrypted.", [tfplan.addr(rc)])
}

# --- MSK: the live defect this repo shipped ---------------------------------

deny contains msg if {
	some rc in tfplan.resources("aws_msk_cluster")
	ca := tfplan.block(rc, "client_authentication")
	ca.unauthenticated == true
	msg := sprintf("%s: MSK allows unauthenticated access.", [tfplan.addr(rc)])
}

deny contains msg if {
	some rc in tfplan.resources("aws_msk_cluster")
	eit := rc.change.after.encryption_info[0].encryption_in_transit[0]
	eit.client_broker != "TLS"
	msg := sprintf("%s: MSK client-broker encryption is %v, must be TLS.", [tfplan.addr(rc), eit.client_broker])
}

# --- ElastiCache ------------------------------------------------------------

deny contains msg if {
	some rc in tfplan.resources("aws_elasticache_replication_group")
	tfplan.not_true(rc, "transit_encryption_enabled")
	msg := sprintf("%s: ElastiCache transit encryption is disabled.", [tfplan.addr(rc)])
}

deny contains msg if {
	some rc in tfplan.resources("aws_elasticache_replication_group")
	tfplan.not_true(rc, "at_rest_encryption_enabled")
	msg := sprintf("%s: ElastiCache at-rest encryption is disabled.", [tfplan.addr(rc)])
}

# --- ECR --------------------------------------------------------------------

deny contains msg if {
	some rc in tfplan.resources("aws_ecr_repository")
	rc.change.after.image_tag_mutability == "MUTABLE"
	msg := sprintf("%s: ECR image tags are mutable; image provenance cannot be trusted.", [tfplan.addr(rc)])
}

# --- Security groups: admin/data ports open to the world --------------------
#
# The Verified Access endpoint SG is the one legitimate 0.0.0.0/0:443 ingress --
# it terminates and authenticates every request. It is exempted by tag, not by
# turning the rule off.

is_ava_endpoint(rc) if endswith(rc.change.after.tags.Name, "-ava-endpoint-sg")

deny contains msg if {
	some rc in tfplan.resources("aws_vpc_security_group_ingress_rule")
	rc.change.after.cidr_ipv4 in world
	not is_ava_endpoint(rc)
	msg := sprintf("%s: security group ingress from 0.0.0.0/0.", [tfplan.addr(rc)])
}

deny contains msg if {
	some rc in tfplan.resources("aws_vpc_security_group_ingress_rule")
	rc.change.after.cidr_ipv6 in world_v6
	not is_ava_endpoint(rc)
	msg := sprintf("%s: security group ingress from ::/0.", [tfplan.addr(rc)])
}

deny contains msg if {
	some rc in tfplan.resources("aws_security_group")
	some rule in tfplan.blocks(rc, "ingress")
	some cidr in rule.cidr_blocks
	cidr in world
	rule.from_port in admin_ports
	msg := sprintf("%s: inline ingress opens admin/data port %v to 0.0.0.0/0.", [tfplan.addr(rc), rule.from_port])
}

# --- IAM: no *:* --------------------------------------------------------------

deny contains msg if {
	some rc in tfplan.resources("aws_iam_role_policy")
	doc := json.unmarshal(rc.change.after.policy)
	some stmt in doc.Statement
	stmt.Effect == "Allow"
	action_is_star(stmt.Action)
	resource_is_star(stmt.Resource)
	msg := sprintf("%s: IAM inline policy allows Action:* on Resource:*.", [tfplan.addr(rc)])
}

action_is_star(a) if a == "*"

action_is_star(a) if {
	is_array(a)
	"*" in a
}

resource_is_star(r) if r == "*"

resource_is_star(r) if {
	is_array(r)
	"*" in r
}
