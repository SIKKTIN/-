extends SceneTree

var game

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","lockpick","strong"],26)
	root.grab_focus()
	game.actors[0].position = Vector2(540,970)
	game.map_camera.locate_selected()
	game.presentation.lighting.set_period("night")
	var caps: Array = [0,55]
	var results: Array = []
	for cap in caps:
		Engine.max_fps = cap
		game.command_move(0,Vector2(540,1320))
		await create_timer(0.25).timeout
		var timings: Array = []
		var focus_frames := 0
		for index in range(180):
			if not game.orders.active.has(0):
				game.command_move(0,Vector2(540,970 if game.actors[0].position.y > 1100 else 1320))
			var begin := Time.get_ticks_usec()
			await frame()
			timings.append((Time.get_ticks_usec()-begin)/1000.0)
			focus_frames += int(root.has_focus())
		timings.sort()
		results.append({"cap":cap,"p50_ms":timings[90],"p95_ms":timings[171],"p99_ms":timings[178],"max_ms":timings.back(),"mean_ms":timings.reduce(func(a,b):return a+b,0.0)/timings.size(),"focus_frames":focus_frames,"samples":180})
	var driver := RenderingServer.get_current_rendering_driver_name()
	var method := RenderingServer.get_current_rendering_method()
	var report := {"driver":driver,"method":method,"refresh_hz":DisplayServer.screen_get_refresh_rate(),"vsync":DisplayServer.window_get_vsync_mode(),"results":results,"lights":game.presentation.lighting.lamps.size(),"occluders":game.presentation.lighting.occluders.size(),"captures":game.captures,"scope":"Native Windows moving-follow camera with night lights/guard, safe-corridor start fixture. Framebuffer clocks only, no physical display scanout or human verdict."}
	FileAccess.open("res://docs/tests/p26-frame-pacing-%s.json"%driver,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	root.get_texture().get_image().save_png("res://docs/tests/p26-frame-pacing-%s.png"%driver)
	print(JSON.stringify(report))
	game.presentation.stop_all()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit()
