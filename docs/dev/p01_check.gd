extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	var results := {}
	for window_size in [Vector2i(1280,720), Vector2i(960,540)]:
		root.content_scale_size = Vector2i(1200,720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.size = window_size
		await process_frame
		await process_frame
		game.reset_round()
		var transform: Transform2D = game.get_global_transform_with_canvas()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = transform * Vector2(180,235)
		game._unhandled_input(press)
		var move := InputEventMouseMotion.new()
		move.position = transform * Vector2(300,235)
		game._unhandled_input(move)
		game._move_dragged(0.6)
		game.end_drag()
		results[str(window_size)] = {"requested_size": str(window_size), "actual_size": str(root.size), "viewport": str(root.get_visible_rect().size), "only_first_moved": game.actors[0].position == Vector2(300,235) and game.actors[1].position == Vector2(235,375) and game.actors[2].position == Vector2(185,510)}
	game.reset_round()
	game.scale = Vector2(0.75,0.75)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(180,235) * 0.75
	game._unhandled_input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(300,235) * 0.75
	game._unhandled_input(move)
	game._move_dragged(0.6)
	game.end_drag()
	results.scaled_canvas_drag = game.actors[0].position == Vector2(300,235)
	results.guard_not_draggable = not game.begin_drag_at(game.guard_position)
	game.cards[2].emit_signal("pressed")
	results.card_selects_third = game.selected_actor_id == 2
	game.reset_round()
	results.reset_restores_all = game.actors[0].position == Vector2(180,235) and game.actors[1].position == Vector2(235,375) and game.actors[2].position == Vector2(185,510)
	var passed: bool = results.scaled_canvas_drag and results.guard_not_draggable and results.card_selects_third and results.reset_restores_all
	for window_size in [Vector2i(1280,720), Vector2i(960,540)]:
		passed = passed and results[str(window_size)].only_first_moved and results[str(window_size)].actual_size == str(window_size)
	results.passed = passed
	var file := FileAccess.open("res://docs/dev/p01-check-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("P01_RESULT ", JSON.stringify(results))
	quit(0 if passed else 1)
