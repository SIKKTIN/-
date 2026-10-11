extends RefCounted

# Reserve the upper canvas bands for lighting, warnings and world information.
# All physical art shares this transform, including roofs, actors and props.
static func for_y(y: float, map_end_y: float) -> int:
	return clampi(32+floori(y*minf(1.0,1700.0/maxf(1.0,map_end_y))),32,1790)
