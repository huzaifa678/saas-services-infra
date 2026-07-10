package terraform.governance

# Advisory controls (`warn`). Reported on the MR, non-blocking. Promote a rule to
# a `deny` in security.rego once the fleet is clean of it.

import data.lib.tfplan

required_tags := {"Environment", "ManagedBy", "Project"}

warn contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	tfplan.is_protected
	tfplan.not_true(rc, "deletion_protection")
	msg := sprintf("%s: RDS deletion_protection is off in a protected environment.", [tfplan.addr(rc)])
}

warn contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	tfplan.is_protected
	rc.change.after.skip_final_snapshot == true
	msg := sprintf("%s: RDS skip_final_snapshot is true in a protected environment.", [tfplan.addr(rc)])
}

warn contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	tfplan.is_prod
	tfplan.not_true(rc, "multi_az")
	msg := sprintf("%s: prod RDS is not Multi-AZ.", [tfplan.addr(rc)])
}

warn contains msg if {
	some rc in tfplan.resources("aws_elasticache_replication_group")
	tfplan.is_protected
	tfplan.not_true(rc, "multi_az_enabled")
	msg := sprintf("%s: ElastiCache is not Multi-AZ in a protected environment.", [tfplan.addr(rc)])
}

# Tag hygiene. default_tags apply the mandatory set at the provider level, so this
# only fires on resources that carry an explicit tags map missing a key.
warn contains msg if {
	some rc in tfplan.resources("aws_db_instance")
	tags := object.get(rc.change.after, "tags", {})
	count(tags) > 0
	some t in required_tags
	not tags[t]
	msg := sprintf("%s: missing required tag %q.", [tfplan.addr(rc), t])
}
