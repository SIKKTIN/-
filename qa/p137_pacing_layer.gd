extends "res://scripts/presentation/scene_layers.gd"
var draw_ms:=0.0
func _draw() -> void:
	var mark:=Time.get_ticks_usec()
	super._draw()
	draw_ms=(Time.get_ticks_usec()-mark)/1000.0
