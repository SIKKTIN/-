extends "res://scripts/presentation/scene_layers.gd"
var draws: Array = []
func _draw() -> void:
	var started := Time.get_ticks_usec()
	super._draw()
	draws.append({"ms":(Time.get_ticks_usec()-started)/1000.0,"event":str(game.get_meta("roof_probe_event","warm"))})
