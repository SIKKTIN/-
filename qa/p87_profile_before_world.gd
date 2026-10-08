extends "res://qa/p87_before_world.gd"
var path_events: Array=[]
var nav_events: Array=[]
func find_path(from: Vector2,to: Vector2,actor=null,avoid=false,ignore_crate=false) -> PackedVector2Array:
 var start:=Time.get_ticks_usec()
 var result=super.find_path(from,to,actor,avoid,ignore_crate)
 var ms=(Time.get_ticks_usec()-start)/1000.0
 var event={"ms":ms,"from":str(from),"to":str(to),"points":result.size(),"role":actor.get_script().resource_path if actor!=null else "null","budget":ai_path_budget_active}
 if ms>2:event.stack=get_stack().slice(0,5).map(func(s):return str(s.function))
 path_events.append(event)
 return result
func _rebuild_navigation() -> void:
 var start:=Time.get_ticks_usec()
 super._rebuild_navigation()
 nav_events.append((Time.get_ticks_usec()-start)/1000.0)
