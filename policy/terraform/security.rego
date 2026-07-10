package main

import rego.v1


deny contains msg if {
	some rc in tf_resources("aws_db_instance")
	after(rc).publicly_accessible == true
	msg := sprintf("RDS instance %q must not be publicly accessible (set publicly_accessible=false)", [rc.address])
}


deny contains msg if {
	some rc in tf_resources("aws_db_instance")
	after(rc).storage_encrypted != true
	msg := sprintf("RDS instance %q must set storage_encrypted=true", [rc.address])
}

deny contains msg if {
	some rc in tf_resources("aws_ecr_repository")
	cfg := object.get(after(rc), "encryption_configuration", [])
	count(cfg) == 0
	msg := sprintf("ECR repository %q must define an encryption_configuration (KMS)", [rc.address])
}


admin_ports := {22, 3389, 3306, 5432, 6379, 27017, 9092, 9200}

deny contains msg if {
	some rc in tf_resources("aws_security_group")
	some ingress in object.get(after(rc), "ingress", [])
	opens_world(ingress.cidr_blocks)
	some p in admin_ports
	port_in_range(ingress, p)
	msg := sprintf("Security group %q exposes admin/data port %d to 0.0.0.0/0", [rc.address, p])
}

deny contains msg if {
	some rc in tf_resources("aws_security_group_rule")
	a := after(rc)
	a.type == "ingress"
	opens_world(a.cidr_blocks)
	some p in admin_ports
	port_in_range(a, p)
	msg := sprintf("Security group rule %q exposes admin/data port %d to 0.0.0.0/0", [rc.address, p])
}


deny contains msg if {
	some rc in tf_resources("aws_iam_policy")
	stmt := _policy_statements(after(rc).policy)[_]
	_effect_allow(stmt)
	_has_wildcard(stmt.Action)
	_has_wildcard(stmt.Resource)
	msg := sprintf("IAM policy %q grants Action:* on Resource:* — scope it down", [rc.address])
}

_policy_statements(doc) := stmts if {
	is_string(doc)
	parsed := json.unmarshal(doc)
	stmts := _as_array(parsed.Statement)
}

_as_array(x) := x if is_array(x)

_as_array(x) := [x] if not is_array(x)

_effect_allow(stmt) if stmt.Effect == "Allow"

_has_wildcard(v) if v == "*"

_has_wildcard(v) if {
	is_array(v)
	"*" in {x | some x in v}
}
