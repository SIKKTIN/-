extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.load_room("r01",["chat","lockpick","strong"],33)
	var changed: bool = g.world._move_crate(Vector2(171,-57))
	var transitions: int = 0
	var route: int = g.guard.route_index
	var blocked_time: float = 0
	for frame in range(60*90):
		g._process(1.0/60.0)
		if g.guard.route_index != route:
			transitions += 1
			route = g.guard.route_index
		blocked_time = maxf(blocked_time,g.guard.stalled_time)
	var passed: bool = changed and transitions > 12 and g.guard.skipped_waypoints > 0 and blocked_time <= 0.81
	var report := {"passed":passed,"box_moved_over_patrol_point":changed,"transitions":transitions,"skipped_blocked_waypoints":g.guard.skipped_waypoints,"max_stall":blocked_time,"snapshot":g.snapshot()}
	var file := FileAccess.open("res://docs/tests/p11-patrol-dynamic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PATROL_DYNAMIC ",JSON.stringify({"passed":passed,"transitions":transitions,"skipped":g.guard.skipped_waypoints,"max_stall":blocked_time}))
	g.queue_free()
	await process_frame
	quit(0 if passed else 1)
