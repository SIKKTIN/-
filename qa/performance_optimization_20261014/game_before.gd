extends "res://scripts/core/escape_game.gd"
func _ready():
 super._ready()
 routines=preload("res://qa/performance_optimization_20261014/daily_before.gd").new(self)
func _process(delta):
 preload("res://docs/dev/performance-optimization-2026-10-14/game_frame.gd").tick(self,delta)
