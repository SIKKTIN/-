extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["lockpick","chat","backpack"],70)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	# Normal game loop: no manual stepping or disabling scene processing.
	await create_timer(18.0,true,false,true).timeout
	var started := Time.get_ticks_usec()
	var previous := started
	var times: Array = []
	while Time.get_ticks_usec()-started < 8000000:
		await frame()
		var now := Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
	var total := 0.0
	for value in times: total += value
	times.sort()
	var checks := {"only_player_hud":game.cards[0].visible and not game.cards[1].visible and not game.cards[2].visible,"supervisor_exists":is_instance_valid(game.workshop.overseer),"work_gate_closed":game.world.access_by_id("workshop-entry").closed,"no_false_arrests":game.captures == 0,"fps_above_45":times.size()*1000.0/total > 45,"both_npcs_working":game.routines.is_working(1) and game.routines.is_working(2),"lead_selected":game.selected_actor_id==0,"npcs_read_only":game.cards[1].disabled and game.cards[2].disabled,"default_work_progresses":game.routines.work_minutes[1]>0 and game.routines.work_minutes[2]>0,"unpaused":not paused}
	root.get_texture().get_image().save_png("res://docs/tests/p74-live-runtime.png")
	# Sample a real unpaused conversation during free time, with no manual stepping.
	game.schedule.clock_elapsed = (1110.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	var target: Dictionary = game.dialogue.targets().filter(func(t): return t.role=="merchant")[0]
	for offset in [Vector2(70,0),Vector2(-70,0),Vector2(0,70),Vector2(0,-70)]:
		if game.world.can_place_circle(target.node.position+offset,17,game.actors[0],true):
			game.actors[0].position = target.node.position+offset
			break
	checks.real_dialogue_opens = game.dialogue.open(str(target.id))
	game.map_camera.center_on(game.actors[0].position)
	game.map_camera.following = false
	var dialog_start := Time.get_ticks_usec()
	var dialog_frames := 0
	var dialog_clock: float = game.schedule.clock_elapsed
	while Time.get_ticks_usec()-dialog_start < 3000000:
		await frame()
		dialog_frames += 1
	var dialog_fps: float = dialog_frames*1000000.0/(Time.get_ticks_usec()-dialog_start)
	checks.dialogue_remains_open = game.dialogue.panel.visible
	checks.dialogue_does_not_pause_time = game.schedule.clock_elapsed>dialog_clock and not paused
	checks.dialogue_fps_above_45 = dialog_fps>45
	root.get_texture().get_image().save_png("res://docs/tests/p74-live-dialogue.png")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"failed":failed,"fps":times.size()*1000.0/total,"p95_ms":times[floori(times.size()*0.95)],"frames":times.size(),"dialogue_fps":dialog_fps,"engine_fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"viewport":[1200,720],"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"routines":game.routines.snapshot(),"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")}
	FileAccess.open("res://docs/tests/p74-live-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
