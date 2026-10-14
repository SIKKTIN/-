extends "res://scripts/world/navigation_connectivity.gd"
var audit_parts: Dictionary={}
func span(key: String, mark: int):audit_parts[key]=audit_parts.get(key,0.0)+(Time.get_ticks_usec()-mark)/1000.0
func _build_chunk(grid: AStarGrid2D,index: Dictionary,chunk: Vector2i):
 var mark:=Time.get_ticks_usec()
 super._build_chunk(grid,index,chunk)
 span("chunk_build",mark)
func _link_chunk(index: Dictionary,chunk: Vector2i):
 var mark:=Time.get_ticks_usec()
 super._link_chunk(index,chunk)
 span("chunk_link",mark)
func _components(index: Dictionary):
 var mark:=Time.get_ticks_usec()
 super._components(index)
 span("graph_components",mark)
