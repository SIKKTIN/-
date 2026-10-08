extends "res://scripts/presentation/guard_warning.gd"
var cost_ms:=0.0
func refresh(view: Rect2, enabled: bool, day: bool) -> void:
 var start:=Time.get_ticks_usec()
 super.refresh(view,enabled,day)
 cost_ms=(Time.get_ticks_usec()-start)/1000.0
