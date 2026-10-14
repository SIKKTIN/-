extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
var profile_total_ms:=0.0
func _ready() -> void:
	preload("res://qa/p136_pacing_bootstrap.gd").configure(self)
	world.pathfinding=preload("res://qa/p136_pacing_navigation.gd").new(world)
func _process(delta: float) -> void:
	var mark:=Time.get_ticks_usec()
	world.pathfinding.frame_records.clear()
	preload("res://qa/p136_pacing_frame.gd").tick(self,delta)
	profile_total_ms=(Time.get_ticks_usec()-mark)/1000.0
