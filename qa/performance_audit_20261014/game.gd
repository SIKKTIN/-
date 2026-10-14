extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary = {}
var profile_total_ms: float = 0
func _make_world():
 return preload("res://qa/performance_audit_20261014/world.gd").new()
func _ready() -> void:
 preload("res://qa/performance_audit_20261014/bootstrap.gd").configure(self)
func _process(delta: float) -> void:
 var mark: int = Time.get_ticks_usec()
 preload("res://qa/performance_audit_20261014/frame.gd").tick(self,delta)
 profile_total_ms=(Time.get_ticks_usec()-mark)/1000.0
