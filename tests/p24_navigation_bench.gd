extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","strong"],24)
	var actor = game.actors[0]
	var goals := [Vector2(1020,310),Vector2(1430,1250),Vector2(540,970),Vector2(2235,790)]
	var timings: Array = []
	var counts := {"reachable":0,"unreachable":0}
	var begin := Time.get_ticks_usec()
	game.world.find_path(actor.position,goals[0],actor,true)
	var cold_ms := (Time.get_ticks_usec()-begin)/1000.0
	for index in range(80):
		begin = Time.get_ticks_usec()
		var path: PackedVector2Array = game.world.find_path(actor.position,goals[index%4],actor,true)
		timings.append((Time.get_ticks_usec()-begin)/1000.0)
		counts["unreachable" if path.is_empty() else "reachable"] += 1
	timings.sort()
	var suffix := "before" if "before" in OS.get_cmdline_user_args() else "after"
	var report := {"scope":"Same-machine headless R04 synchronous queries with actor avoidance, 80 warm alternating goals; not rendered frame/phone timing.","cold_ms":cold_ms,"median_ms":timings[40],"p95_ms":timings[75],"max_ms":timings[79],"counts":counts,"queries":80}
	var file := FileAccess.open("res://docs/tests/p24-navigation-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit()
