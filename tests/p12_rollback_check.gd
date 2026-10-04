extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var p = game.presentation
	var checks := {}
	checks.visible_head_can_select = game.select_at(game.actors[0].position+Vector2(0,-37))
	var transform: Transform2D = game.get_global_transform_with_canvas()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = transform * Vector2(180,198)
	game._unhandled_input(press)
	press.button_index = MOUSE_BUTTON_RIGHT
	press.position = transform * Vector2(300,235)
	game._unhandled_input(press)
	game.orders.tick(0.6)
	game.orders.clear()
	checks.transformed_input_only_moves_first = game.actors[0].position == Vector2(300,235) and game.actors[1].position == Vector2(235,375) and game.actors[2].position == Vector2(185,510)
	game.reset_round(["chat","lockpick","strong"],33)
	game.guard.position = Vector2(690,250)
	game.actors[0].position = Vector2(620,215)
	game.actors[1].position = Vector2(440,395)
	game.skills.toggle(0)
	game.skills.toggle(1)
	game.select_actor(2)
	p.tick(0.1)
	checks.two_loops_on_independent_actions = p.loops.chat_loop.playing and p.loops.lockpick_loop.playing and game.skills.actions.size() == 2
	checks.selection_not_action = game.actors[2].selected and game.actors[0].action_state == "chatting" and game.actors[1].action_state == "lockpicking"
	game.actors[2].moved_this_frame = true
	p.tick(0.4)
	checks.walk_on_actual_move = p.visuals[2].frame_name.begins_with("walk_")
	game.actors[2].moved_this_frame = false
	p.tick(0.1)
	checks.stop_returns_idle = p.visuals[2].frame_name == "idle"
	checks.frame_anchor_height = true
	for visual in p.visuals:
		for frame in ["idle","walk_a","walk_b"]:
			var region: Array = visual.definition.frames[frame]
			var anchor: Array = visual.definition.anchor[frame]
			var ratio: float = float(visual.definition.world_height) / region[3]
			checks.frame_anchor_height = checks.frame_anchor_height and absf((region[3]-anchor[1])*ratio) < 0.5
	paused = true
	await process_frame
	await process_frame
	checks.pause_stops_loops = not p.loops.chat_loop.playing and not p.loops.lockpick_loop.playing
	paused = false
	p.tick(0.1)
	checks.resume_actual_actions = p.loops.chat_loop.playing and p.loops.lockpick_loop.playing
	game.capture_actor(1)
	p.tick(0.1)
	checks.capture_stops_only_target_loop = not p.loops.lockpick_loop.playing and p.loops.chat_loop.playing and p.events.any(func(e): return e.id == "captured")
	game.skills.cancel(0,"测试：主动结束聊天")
	p.tick(0.1)
	checks.cancel_reason_and_stop = not p.loops.chat_loop.playing and game.status_text.contains("主动结束聊天") and p.events.any(func(e): return e.id == "cancelled")
	game.actors[2].position = Vector2(440,617)
	game.world.move_actor(game.actors[2],Vector2(16,0),true,16)
	p.tick(0.1)
	checks.real_push_sound = game.world.push_distance > 0 and p.loops.crate_move_loop.playing
	p.tick(0.1)
	checks.stationary_box_silent = not p.loops.crate_move_loop.playing
	game.reset_round(["lockpick","chat","strong"],11)
	game.actors[0].position = Vector2(440,395)
	game.use_selected_skill()
	game.skills.tick(4.01)
	p.tick(0.1)
	checks.open_stops_lock_loop = game.world.door_open and not p.loops.lockpick_loop.playing and p.events.any(func(e): return e.id == "door_open")
	game.reset_round(["chat","lockpick","strong"],33)
	game.actors[0].escaped = true
	p.tick(0.1)
	checks.escape_hidden_and_cue = not p.visuals[0].visible and p.events.any(func(e): return e.id == "escaped")
	for actor in game.actors:
		actor.escaped = true
	game.phase = "complete"
	p.tick(0.1)
	checks.complete_stops_all_loops = p.loops.values().all(func(player): return not player.playing) and p.events.any(func(e): return e.id == "complete")
	game.load_room("r02",["chat","lockpick","strong"],33)
	game.set_process(false)
	checks.ui_inside_viewport = game.cards.all(func(c): return c.position.x+c.size.x <= 1200 and c.position.y+c.size.y <= 720)
	checks.loop_streams_configured = p.loops.values().all(func(player): return player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	checks.chinese_font = p.font.has_char("逃".unicode_at(0)) and p.font.has_char("锁".unicode_at(0))
	await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "%dx%d" % [root.size.x,root.size.y]
	var picture := root.get_texture().get_image()
	checks.screenshot_is_actual_window = picture.get_size() == root.size
	checks.window_test_size = root.size in [Vector2i(1280,720),Vector2i(960,540)]
	picture.save_png("res://docs/tests/p12-rollback-%s.png" % suffix)
	var report := {"window":[root.size.x,root.size.y],"image":[picture.get_width(),picture.get_height()],"viewport":str(root.get_visible_rect().size),"checks":checks,"presentation":p.snapshot(),"passed":checks.values().all(func(value): return value == true),"human_listening":"not yet verified"}
	var file := FileAccess.open("res://docs/tests/p12-rollback-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("P08_PRESENTATION ",JSON.stringify({"window":report.window,"passed":report.passed,"checks":checks}))
	p.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit(0 if report.passed else 1)
