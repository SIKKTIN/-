extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
func _ready() -> void:
	preload("res://qa/p136_bootstrap.gd").configure(self)
func _process(delta: float) -> void:
	preload("res://qa/p136_frame.gd").tick(self,delta)
