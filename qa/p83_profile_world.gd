extends "res://qa/p79_profile_world.gd"
var navigation_events: Array=[]
func _rebuild_navigation() -> void:
 var before=Time.get_ticks_usec()
 var old={}
 var new={}
 for r in navigation_solids:old[r]=true
 for r in static_solids:new[r]=true
 var diffs=old.keys().filter(func(r):return not new.has(r)).size()+new.keys().filter(func(r):return not old.has(r)).size()
 var changed=navigation_layout!=[bounds.merge(exit_area),guard_zone,not boundary_solids.is_empty()]
 super._rebuild_navigation()
 var event={"ms":(Time.get_ticks_usec()-before)/1000.0,"layout_changed":changed,"solids_changed":diffs,"boundary_count":boundary_solids.size()}
 navigation_events.append(event)
 if event.ms>8:print("NAV_EVENT ",JSON.stringify(event))

func find_path(from: Vector2, to: Vector2, actor=null, avoid=false, ignore_crate=false) -> PackedVector2Array:
 var before=Time.get_ticks_usec()
 var result=super.find_path(from,to,actor,avoid,ignore_crate)
 var ms=(Time.get_ticks_usec()-before)/1000.0
 if ms>8:print("SLOW_PATH ",JSON.stringify({"ms":ms,"from":str(from),"to":str(to),"from_room":room_visibility.room_at(from) if room_visibility!=null else "","to_room":room_visibility.room_at(to) if room_visibility!=null else "","points":result.size(),"role":actor.get_script().resource_path if actor!=null else "null"}))
 return result
