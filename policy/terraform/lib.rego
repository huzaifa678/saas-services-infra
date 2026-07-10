package main

import rego.v1

tf_resources(kind) := [rc |
	some rc in input.resource_changes
	rc.type == kind
	rc.mode == "managed"
	_is_create_or_update(rc)
]

_is_create_or_update(rc) if {
	some action in rc.change.actions
	action in {"create", "update"}
}

after(rc) := rc.change.after if {
	rc.change.after != null
} else := {}

opens_world(cidrs) if "0.0.0.0/0" in {c | some c in cidrs}

opens_world(cidrs) if "::/0" in {c | some c in cidrs}

port_in_range(rule, port) if {
	rule.from_port <= port
	rule.to_port >= port
}
