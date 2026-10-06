extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sample(game, image: Image, point: Vector2) -> float:
	var pixel: Vector2 = game.get_global_transform_with_canvas()*point
	return image.get_pixel(int(pixel.x),int(pixel.y)).get_luminance()

func plinth_edge(game, image: Image, x: float) -> float:
	var best_drop := -100.0
	var edge := -1.0
	for y in range(1218,1234):
		var drop := 0.0
		for dx in range(-4,5): drop += sample(game,image,Vector2(x+dx,y-1))-sample(game,image,Vector2(x+dx,y+1))
		if drop > best_drop:
			best_drop = drop
			edge = y
	return edge

func run() -> void:
	root.content_scale_size = Vector2i(1200,720)
	root.size = root.content_scale_size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],55)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.get_node("HUD").hide()
	game.presentation.tick(0)
	game.map_camera.following = false
	game.map_camera.zoom = Vector2(2,2)
	game.map_camera.position = Vector2(690,1080)
	game.map_camera.force_update_scroll()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://docs/tests/p57-first-version-baseline.png")
	var checks := {
		"24wide_wall_keeps_dark_side":image.get_pixel(105,500).get_luminance() < image.get_pixel(75,500).get_luminance()*0.85,
		"20wide_wall_keeps_dark_side":image.get_pixel(1197,500).get_luminance() < image.get_pixel(1170,500).get_luminance()*0.85,
		"physical_widths_unchanged":game.world.walls[9].size.x == 24 and game.world.walls[12].size.x == 20
	}
	checks.corner_plinth_aligns_with_original = absf(plinth_edge(game,image,770)-plinth_edge(game,image,825)) <= 2
	print("PLINTH_EDGES ",plinth_edge(game,image,770)," ",plinth_edge(game,image,825))
	checks.corner_top_is_above_front = sample(game,image,Vector2(760,1159)) > sample(game,image,Vector2(760,1242))*1.2
	game.map_camera.position = Vector2(1740,1080)
	game.map_camera.force_update_scroll()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var right_image := root.get_texture().get_image()
	right_image.save_png("res://docs/tests/p57-first-version-right-baseline.png")
	checks.right_side_mirrored = sample(game,right_image,Vector2(2002,1380)) < sample(game,right_image,Vector2(2018,1380))*0.9
	checks.kitchen_right_side_mirrored = sample(game,right_image,Vector2(1912,1340)) < sample(game,right_image,Vector2(1925,1340))*0.9
	print("RIGHT_PIXELS ",sample(game,right_image,Vector2(2002,1380))," ",sample(game,right_image,Vector2(2018,1380))," ",sample(game,right_image,Vector2(1912,1340))," ",sample(game,right_image,Vector2(1925,1340)))
	var failures: Array = checks.keys().filter(func(k): return not checks[k])
	var result := {"checks":checks,"passed":checks.size()-failures.size(),"total":checks.size(),"failed":failures,"note":"Actual Godot camera zoom2 projection, unedited screenshot. Tests both24 exterior and20 interior full-width top/side mapping."}
	FileAccess.open("res://docs/tests/p57-wall-detail-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
