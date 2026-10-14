extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
var profile_total_ms: float=0
func _ready():preload("res://qa/android_performance_20261014/bootstrap.gd").configure(self)
func _process(delta: float):
	var start:=Time.get_ticks_usec()
	preload("res://qa/android_performance_20261014/frame.gd").tick(self,delta)
	profile_total_ms=(Time.get_ticks_usec()-start)/1000.0
