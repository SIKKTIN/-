extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
func _ready() -> void:
	preload("res://qa/p137_bootstrap.gd").configure(self)
func _process(delta: float) -> void:
	preload("res://qa/p137_frame.gd").tick(self,delta)
