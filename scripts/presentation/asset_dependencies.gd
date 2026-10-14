@tool
extends RefCounted

# Follow IDs in current map/profile and their assembly/state references.
# Catalog entries remain available for authoring; only needed pixels load.
static func ids(data: Variant, profile: Dictionary, definitions: Dictionary) -> Dictionary:
	var result: Dictionary={}
	_collect(data,definitions,result)
	_collect(profile,definitions,result)
	# Renderers have legacy defaults and state-driven gates outside room JSON.
	for id in ["cafeteria_coping_v23","cafeteria_wall_front_v23","prison_gate_closed_v37","prison_gate_open_v37"]:
		_collect(id,definitions,result)
	return result

static func _collect(value: Variant, definitions: Dictionary, result: Dictionary) -> void:
	if value is String:
		if definitions.has(value) and not result.has(value):
			result[value]=true
			_collect(definitions[value],definitions,result)
	elif value is Dictionary:
		for key in value:
			_collect(key,definitions,result)
			_collect(value[key],definitions,result)
	elif value is Array:
		for entry in value: _collect(entry,definitions,result)
