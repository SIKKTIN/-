extends RefCounted

# Reserve the upper canvas bands for lighting, warnings and world information.
# All physical art shares this transform, including roofs, actors and props.
static func for_y(y: float, map_end_y: float) -> int:
	return clampi(32+floori(y*minf(1.0,1700.0/maxf(1.0,map_end_y))),32,1790)

static func for_raised_door(gate: Dictionary, map_end_y: float) -> int:
	if gate.get("body_depth_limited",false):
		# Integer depth buckets span several world pixels. Sorting one band
		# below the first legal foreground foot position prevents an equal-Z
		# door from hiding a person already standing in front of its base.
		var front: float = preload("res://scripts/core/actor_footprint.gd").front_contact_y(gate.rect)
		return for_y(front,map_end_y)-1
	return for_y(gate.rect.end.y,map_end_y)+1
