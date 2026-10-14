extends "res://scripts/world/prison_world.gd"
func set_access_closed(id: String, closed: bool, reset_progress := false) -> void:
	var gate := access_by_id(id)
	if gate.is_empty(): return
	if gate.has("linked_to"):
		set_access_closed(str(gate.linked_to),closed,reset_progress)
		return
	# Timed/manual closure waits for the complete body to clear the leaf.
	# Forced confinement still closes immediately before its landing move.
	# Only defer an open leaf's closure. Reapplying a locked state must never
	# reopen that door because somebody approaches or overlaps its boundary.
	if closed and not reset_progress and actors.any(func(a):return not a.escaped and door_closure_overlap(a,gate)): closed=false
	if reset_progress: gate.progress = 0.0
	var changed: bool = bool(gate.closed)!=closed
	gate.closed = closed
	for companion in access_doors:
		if str(companion.get("linked_to",""))!=id:continue
		changed=changed or bool(companion.closed)!=closed
		companion.closed=closed
		if reset_progress:companion.progress=0.0
	if changed:_changed(true)

func update_dorm_doors(locked: bool, keyholders: Variant, occupants: Array = []) -> void:
	dorm_sync_count += 1
	var points: Array = keyholders if keyholders is Array else [keyholders]
	var changed := false
	var gates := dorm_gates()
	if locked != dorms_locked:
		# A new day/night boundary resets the daytime manual choice.
		for gate in gates: gate.erase("manual_closed")
	dorms_locked = locked
	for gate in gates:
		# The guard uses a key and opens the gate before crossing its collider.
		var closure := dorm_closure_rect(gate)
		var key_near: bool = points.any(func(point): return point.distance_to(point.clamp(closure.position,closure.end)) <= 65)
		var closed: bool = (gate.get("manual_door",false) or str(gate.get("kind","dorm")) != "open") and locked and not key_near
		if not locked: closed = bool(gate.get("manual_closed",gate.get("card_controlled",false)))
		if closed and (actors+occupants).any(func(a):return is_instance_valid(a) and a.get("escaped")!=true and Footprint.body_at(a.position).intersects(closure)): closed=false
		if bool(gate.closed) != closed:
			gate.closed = closed
			changed = true
	if changed:
		_changed(true)
