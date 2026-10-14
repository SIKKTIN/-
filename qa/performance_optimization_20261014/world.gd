extends "res://scripts/world/prison_world.gd"
var audit_cache_enabled: bool=false
var audit_closures: Dictionary={}
var audit_dorm_calls: int=0
var audit_configure_ms: float=0
func _init():
 pathfinding=preload("res://qa/performance_optimization_20261014/navigation.gd").new(self)
func configure(config: Dictionary, owner_actors: Array) -> void:
 var mark: int=Time.get_ticks_usec()
 super.configure(config,owner_actors)
 audit_configure_ms=(Time.get_ticks_usec()-mark)/1000.0
func dorm_closure_rect(gate: Dictionary) -> Rect2:
 audit_dorm_calls+=1
 if not audit_cache_enabled:return super.dorm_closure_rect(gate)
 var key: String=str(gate.get("id",gate))
 if not audit_closures.has(key):audit_closures[key]=super.dorm_closure_rect(gate)
 return audit_closures[key]
