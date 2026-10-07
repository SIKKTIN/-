extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	game.schedule.clock_elapsed = (719.8-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	for actor in game.actors:
		actor.position = game.routines._target(actor.actor_id,"work")
		actor.immune_until = INF
	game.orders.clear()
	game.routines.tick()
	game.map_camera.following = false
	game.map_camera.center_on(Vector2(1190,760))
	var officer = game.workshop.overseer
	var started := Time.get_ticks_usec()
	var previous := started
	var before: Vector2 = officer.position
	var max_speed := 0.0
	var frames := 0
	var inside_hidden := false
	var workshop := false
	var factory := false
	var completed := false
	var pictures := {}
	var traces: Array = []
	var elapsed_before: float = game.elapsed
	var sampled := -1
	while Time.get_ticks_usec()-started < 24500000:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var dt: float = game.elapsed-elapsed_before
		if dt > 0: max_speed = maxf(max_speed,officer.position.distance_to(before)/dt)
		elapsed_before = game.elapsed
		before = officer.position
		previous = now
		frames += 1
		var sample: int = floori((now-started)/1000000.0)
		if sample != sampled:
			sampled = sample
			traces.append({"second":sample,"minute":game.schedule.clock_minutes(),"position":str(officer.position),"status":game.staff_traffic.records[officer.get_instance_id()].status,"legs":str(game.staff_traffic.records[officer.get_instance_id()].legs),"path":str(officer.path),"gate_closed":game.world.access_by_id("workshop-entry").closed})
		if officer.position.x < game.world.bounds.end.x and not officer.visible: inside_hidden = true
		if game.staff_traffic.records[officer.get_instance_id()].status=="offsite": completed = true
		if game.world.access_by_id("workshop-entry").rect.grow(35).has_point(officer.position):
			workshop = true
			if not pictures.has("workshop"):
				root.get_texture().get_image().save_png("res://docs/tests/p75-depart-workshop.png")
				pictures.workshop = true
		if officer.position.x > 1750: game.map_camera.center_on(Vector2(2250,850))
		if game.world.door.grow(35).has_point(officer.position):
			factory = true
			if not pictures.has("factory"):
				root.get_texture().get_image().save_png("res://docs/tests/p75-depart-factory.png")
				pictures.factory = true
	var record: Dictionary = game.staff_traffic.records[officer.get_instance_id()]
	var fps: float = frames*1000000.0/(Time.get_ticks_usec()-started)
	var checks := {"native_walk_both_gates":workshop and factory,"native_never_hidden_inside":not inside_hidden,"native_departure_finishes":completed,"native_no_teleport":max_speed<216,"native_fps_above_45":fps>45,"native_keeps_identity":is_instance_valid(officer) and game.workshop.overseer==officer,"native_returns_before_1400":record.status=="duty" and game.schedule.clock_minutes()<840 and game.workshop.area.has_point(officer.position)}
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"fps":fps,"max_speed":max_speed,"frames":frames,"clock":game.schedule.clock_minutes(),"status":record.status,"position":[officer.position.x,officer.position.y],"traces":traces}
	FileAccess.open("res://docs/tests/p75-native-departure.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
