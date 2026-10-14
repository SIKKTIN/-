extends "res://scripts/world/prison_world.gd"
var changed_ms: Array=[]
var walls_ms: Array=[]
func _changed(static_changed: bool=false) -> void:
	var mark:=Time.get_ticks_usec()
	super._changed(static_changed)
	changed_ms.append((Time.get_ticks_usec()-mark)/1000.0)
func wall_collision_rects() -> Array[Rect2]:
	var mark:=Time.get_ticks_usec()
	var result:=super.wall_collision_rects()
	walls_ms.append((Time.get_ticks_usec()-mark)/1000.0)
	return result
