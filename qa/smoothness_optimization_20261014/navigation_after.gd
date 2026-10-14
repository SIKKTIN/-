extends "res://scripts/world/world_navigation.gd"
var audit_records: Array=[]
var parts: Dictionary={}
func find_path(from: Vector2,to: Vector2,ignore_actor=null,avoid_actors: bool=false,ignore_crate: bool=false) -> PackedVector2Array:
 parts.clear()
 var mark:=Time.get_ticks_usec()
 var result:=super.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
 audit_records.append({"ms":(Time.get_ticks_usec()-mark)/1000.0,"from":[from.x,from.y],"to":[to.x,to.y],"points":result.size(),"parts":parts.duplicate(),"deferred":world.ai_paths_deferred,"builds":world.navigation_builds})
 return result
func _rebuild_navigation():
 var mark:=Time.get_ticks_usec()
 super._rebuild_navigation()
 parts["grid_update"]=(Time.get_ticks_usec()-mark)/1000.0
func _path_on_grid(from: Vector2,to: Vector2,ignore_actor,avoid_actors: bool,ignore_crate: bool,navigation: AStarGrid2D) -> PackedVector2Array:
 var mark:=Time.get_ticks_usec()
 var result:=super._path_on_grid(from,to,ignore_actor,avoid_actors,ignore_crate,navigation)
 parts["grid_search"] = parts.get("grid_search",0.0)+(Time.get_ticks_usec()-mark)/1000.0
 return result
