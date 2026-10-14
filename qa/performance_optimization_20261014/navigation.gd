extends "res://scripts/world/world_navigation.gd"
var audit_records: Array=[]
func find_path(from: Vector2,to: Vector2,ignore_actor=null,avoid_actors: bool=false,ignore_crate: bool=false) -> PackedVector2Array:
	var mark: int=Time.get_ticks_usec()
	var result: PackedVector2Array=super.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
	audit_records.append({"ms":(Time.get_ticks_usec()-mark)/1000.0,"from":str(from),"to":str(to),"points":result.size(),"deferred":world.ai_paths_deferred,"navigation_builds":world.navigation_builds})
	return result
