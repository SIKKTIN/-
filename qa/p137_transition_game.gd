extends "res://qa/p137_pacing_game.gd"
func _make_world():
	return preload("res://qa/p137_transition_world.gd").new()
