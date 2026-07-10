package lib.tfplan

default environment := "unknown"

environment := input.variables.environment.value

is_prod if environment == "prod"

is_dev if environment == "dev"

is_protected if not is_dev

creating_or_updating(rc) if {
	some action in rc.change.actions
	action in {"create", "update"}
}

resources(resource_type) := [rc |
	some rc in input.resource_changes
	rc.type == resource_type
	creating_or_updating(rc)
	rc.change.after != null
]

known(rc, key) if {
	rc.change.after[key] != null
	not rc.change.after_unknown[key]
}

is_false(rc, key) if {
	known(rc, key)
	rc.change.after[key] == false
}

not_true(rc, key) if is_false(rc, key)

not_true(rc, key) if {
	not rc.change.after[key]
	not rc.change.after_unknown[key]
}

block(rc, key) := b if {
	blocks := rc.change.after[key]
	is_array(blocks)
	count(blocks) > 0
	b := blocks[0]
}

blocks(rc, key) := bs if {
	bs := rc.change.after[key]
	is_array(bs)
}

addr(rc) := rc.address
