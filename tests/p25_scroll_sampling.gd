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
	game.load_room("r04",["chat","lockpick","strong"],25)
	game.set_process(false)
	game.map_camera.following = false
	root.grab_focus()
	var patches: Array = []
	var cameras: Array = []
	var origin := Vector2(600,0)
	for index in range(17):
		game.map_camera.position = origin+Vector2(index/16.0,0)
		game.map_camera.pan_by(Vector2.ZERO)
		game.queue_redraw()
		await frame()
		var captured := root.get_texture().get_image()
		var samples: Array = []
		for y in range(335,365):
			for x in range(400,440):
				var point: Vector2 = root.get_final_transform()*Vector2(x,y)
				var color := captured.get_pixel(roundi(point.x),roundi(point.y))
				samples.append(Vector3(color.r,color.g,color.b))
		patches.append(samples)
		cameras.append(game.get_global_transform_with_canvas().origin.x)
	var changes: Array = []
	var still_pixel_steps := 0
	var pixel_acceleration := 0.0
	for index in range(1,patches.size()):
		var change := 0.0
		for pixel in range(patches[index].size()):
			var difference: Vector3 = patches[index][pixel]-patches[index-1][pixel]
			change += difference.length()
			if difference.length() < 0.00001:
				still_pixel_steps += 1
			if index >= 2:
				pixel_acceleration += (difference-(patches[index-1][pixel]-patches[index-2][pixel])).length()
		changes.append(change/patches[index].size())
	var suffix := "before" if "before" in OS.get_cmdline_user_args() else "after"
	var camera = game.map_camera
	game.actors[0].position = Vector2(800,700)
	camera.locate_selected()
	var velocity := Vector2(220,40)
	var lag_samples: Array = []
	var simulation_time := 0.0
	for index in range(260):
		var dt: float = [1.0/165.0,1.0/30.0,1.0/90.0,1.0/55.0][index%4]
		game.actors[0].position += velocity*dt
		if camera.has_method("tick"):
			camera.tick(dt)
		else:
			camera._process(dt)
		simulation_time += dt
		if simulation_time > 1.5:
			lag_samples.append(game.actors[0].position-camera.VIEW.get_center()-camera.position)
	var mean := Vector2.ZERO
	for lag in lag_samples:
		mean += lag
	mean /= lag_samples.size()
	var lag_jitter := 0.0
	for lag in lag_samples:
		lag_jitter = maxf(lag_jitter,lag.distance_to(mean))
	var report := {"scope":"Native frozen R04 raster floor patch, 17 fractional camera steps across one world unit. Separately simulate linear camera target at varying 30/55/90/165Hz, no gameplay collision/AI claim. Framebuffer evidence, not physical scanout. Viewport and CanvasItem filter enums differ; original viewport 1 already means LINEAR.","viewport_linear_enum":Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR,"root_filter":game.texture_filter,"viewport_filter":root.canvas_item_default_texture_filter,"vsync":DisplayServer.window_get_vsync_mode(),"successive_patch_changes":changes,"still_pixel_steps":still_pixel_steps,"temporal_pixel_acceleration":pixel_acceleration/18000.0,"variable_dt_lag_jitter_world":lag_jitter,"mean_lag":[mean.x,mean.y],"canvas_x":cameras}
	FileAccess.open("res://docs/tests/p25-sampling-%s.json"%suffix,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	root.get_texture().get_image().save_png("res://docs/tests/p25-sampling-%s.png"%suffix)
	print(JSON.stringify(report))
	game.presentation.stop_all()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit()
