extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
var profile_total_ms:=0.0
func _make_world():return preload("res://qa/smoothness_20261014/world.gd").new()
func _process(delta: float):
 profile_sections.clear()
 world.pathfinding.audit_records.clear()
 var mark:=Time.get_ticks_usec()
 preload("res://qa/smoothness_20261014/frame.gd").tick(self,delta)
 profile_total_ms=(Time.get_ticks_usec()-mark)/1000.0
