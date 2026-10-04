extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	var rows: Array = []
	for room in ["r01","r02"]:
		for fps in [30,60,110]:
			g.load_room(room,["chat","lockpick","strong"],33)
			var previous_route: int = g.guard.route_index
			var visits: int = 0
			var samples: Array = []
			for i in range(fps*120):
				g._process(1.0/fps)
				if previous_route != g.guard.route_index:
					visits += 1
					previous_route = g.guard.route_index
				if i % fps == 0:
					samples.append({"second":i/fps,"position":[g.guard.position.x,g.guard.position.y],"route":g.guard.route_index,"path":str(g.guard.path)})
			rows.append({"room":room,"fps":fps,"waypoint_changes":visits,"snapshot":g.guard.snapshot(),"last_samples":samples.slice(-8)})
	var f := FileAccess.open("res://docs/tests/p13-patrol-after.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"\t"))
	f.close()
	var passed: bool = rows.all(func(row): return row.waypoint_changes >= 12 and row.snapshot.skipped_waypoints == 0)
	print("PATROL_AFTER ",JSON.stringify({"passed":passed,"rows":rows.map(func(row): return {"room":row.room,"fps":row.fps,"waypoint_changes":row.waypoint_changes,"skipped":row.snapshot.skipped_waypoints})}))
	g.queue_free()
	await process_frame
	quit(0 if passed else 1)
