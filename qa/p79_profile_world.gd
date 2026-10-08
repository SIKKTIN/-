extends "res://scripts/world/prison_world.gd"
var path_times: Array = []
func find_path(from: Vector2, to: Vector2, actor = null, avoid: bool = false, ignore_crate: bool = false) -> PackedVector2Array:
	var start := Time.get_ticks_usec()
	var result := super.find_path(from,to,actor,avoid,ignore_crate)
	path_times.append((Time.get_ticks_usec()-start)/1000.0)
	return result
