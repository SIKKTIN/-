extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for room in ["r01","r02"]:
		game.load_room(room,["chat","lockpick","strong"],33)
		for size in [384,512]:
			game.floor_tile_size = size
			game.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/tests/p13-%s-floor%d-%dx%d.png" % [room,size,root.size.x,root.size.y])
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit()
