extends SceneTree
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],62)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.get_node("HUD").hide()
	game.presentation.tick(0)
	game.map_camera.following = false
	game.map_camera.zoom = Vector2(2,2)
	game.map_camera.position = Vector2(2520,630)-Vector2(root.size)/4
	game.map_camera.force_update_scroll()
	await frame()
	await frame()
	var before := root.get_texture().get_image()
	var first: int = game.world.fixtures.size()
	for spec in [["cafeteria_t_20_v32",2360,132],["cafeteria_t_v32",2580,136]]:
		game.world.fixtures.append({"asset_id":spec[0],"rect":Rect2(spec[1],500,spec[2],80),"render_size":[spec[2],80],"blocks_movement":false,"blocks_sight":false})

	for spec in [["cafeteria_wall_v_l_20_v32",2420,20],["cafeteria_wall_v_r_20_v32",2490,20],["cafeteria_wall_v_l_v32",2630,24],["cafeteria_wall_v_r_v32",2700,24]]:
		game.world.fixtures.append({"asset_id":spec[0],"rect":Rect2(spec[1],620,spec[2],151.63636363636363),"render_size":[spec[2],151.63636363636363],"blocks_movement":false,"blocks_sight":false})
	game.presentation._refresh_volumes()
	await frame()
	await frame()
	var after := root.get_texture().get_image()
	after.save_png("res://docs/tests/p65-runtime-t-components.png")
	var checks := {}
	for i in range(2):
		var node = game.presentation.volumes[game.world.walls.size()+first+i]
		var width: float = 132 if i == 0 else 136
		checks[str(i)+"_exact_size"] = node.display_rect.size == Vector2(width,80)
		var origin: Vector2 = node.display_rect.position
		for entry in [["left_arm",Vector2(20,12),true],["right_arm",Vector2(width-20,12),true],["stem",Vector2(width/2,60),true],["left_notch",Vector2(20,60),false],["right_notch",Vector2(width-20,60),false]]:
			var pixel := Vector2i(game.get_global_transform_with_canvas()*(origin+entry[1]))
			var a := after.get_pixelv(pixel)
			var b := before.get_pixelv(pixel)
			var distance := Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))
			checks[str(i)+"_"+entry[0]] = distance > 0.04 if entry[2] else distance < 0.02

	for i in range(4):
		var node = game.presentation.volumes[game.world.walls.size()+first+2+i]
		checks["V%d_size" % i] = node.display_rect.size == Vector2(20 if i < 2 else 24,151.63636363636363)
		var pixel := Vector2i(game.get_global_transform_with_canvas()*(node.display_rect.position+Vector2(8,70)))
		var a := after.get_pixelv(pixel)
		var b := before.get_pixelv(pixel)
		checks["V%d_drawn" % i] = Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b)) > 0.04
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p65-runtime-t-components.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
