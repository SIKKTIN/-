extends SceneTree

var game
var checks := {}
var observed: Array = []

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.load_room("r04",["chat","lockpick","strong"],27)
	game.set_process(false)
	root.grab_focus()
	if "baseline" in OS.get_cmdline_user_args():
		var rows: Array = []
		for visual in game.presentation.visuals:
			visual.actor.moved_this_frame = true
			var seen := {}
			var switches: Array = []
			var previous: String = ""
			for i in range(120):
				visual.tick_visual(1.0/60.0)
				seen[visual.frame_name] = true
				if previous != visual.frame_name:
					switches.append((i+1)/60.0)
				previous = visual.frame_name
			rows.append({"actor_id":visual.definition.actor_id,"poses":seen.keys(),"switch_times_seconds":switches,"frame_hold_seconds":visual.definition.initial_walk_frame_seconds})
		FileAccess.open("res://docs/tests/p27-baseline.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"scope":"Existing v03 playback at 60Hz fixture, two seconds actual-move flag; no physical/human timing claim."},"\t"))
		game.presentation.stop_all()
		root.remove_child(game)
		game.queue_free()
		await process_frame
		quit()
		return
	for visual in game.presentation.visuals:
		var id: String = str(visual.definition.actor_id)
		var actor = visual.actor
		checks[id+"_eight_frames"] = visual.walk_frames.size() == 8
		checks[id+"_twelve_fps"] = is_equal_approx(visual.walk_fps,12.0)
		actor.moved_this_frame = false
		visual.tick_visual(0)
		var idle_texture = visual.texture
		actor.moved_this_frame = true
		var seen := {}
		var same_height := true
		var visible_heights: Array = []
		for i in range(8):
			visual.tick_visual(0.001 if i == 0 else 1.0/12.0)
			seen[visual.frame_name] = true
			same_height = same_height and visual.destination.size.y > 0
			if visual.texture != null:
				visible_heights.append(visual.texture.get_image().get_used_rect().size.y*visual.destination.size.y/visual.source_region.size.y)
		checks[id+"_all_poses_play"] = seen.size() == 8
		checks[id+"_uses_walk_texture"] = visual.texture != null and visual.texture != idle_texture and same_height and visual.walk_textures.all(func(t): return t != null and t.get_image().has_mipmaps())
		visible_heights.sort()
		var old_region: Array = visual.definition.frames.idle
		var idle_height: float = idle_texture.get_image().get_region(Rect2i(old_region[0],old_region[1],old_region[2],old_region[3])).get_used_rect().size.y*float(visual.definition.world_height)/old_region[3]
		checks[id+"_visible_scale_stable"] = visible_heights.size() == 8 and (visible_heights.back()-visible_heights[0])/visible_heights[4] < 0.08 and absf(visible_heights[4]-idle_height)/idle_height < 0.08
		var before: String = visual.frame_name
		var clock: float = visual.walk_clock
		paused = true
		visual.tick_visual(0.5)
		checks[id+"_pause_freezes"] = visual.frame_name == before and visual.walk_clock == clock
		paused = false
		actor.moved_this_frame = false
		visual.tick_visual(0.1)
		checks[id+"_stop_original_idle"] = visual.frame_name == "idle" and visual.texture == idle_texture and visual.walk_clock == 0
		actor.facing = Vector2.LEFT
		actor.moved_this_frame = true
		visual.tick_visual(0.12)
		checks[id+"_left_mirrors_body"] = visual.flip_h
		actor.facing = Vector2.RIGHT
		visual.tick_visual(0.12)
		checks[id+"_right_restores_body"] = not visual.flip_h
		actor.escaped = true
		visual.tick_visual(0.1)
		checks[id+"_escaped_hidden"] = not visual.visible
		actor.escaped = false
		var endings: Array = []
		for hz in [30,60,120]:
			actor.moved_this_frame = false
			visual.tick_visual(0)
			actor.moved_this_frame = true
			for i in range(hz*2):
				visual.tick_visual(1.0/hz)
			visual.tick_visual(0.125)
			endings.append(visual.frame_name)
		checks[id+"_rate_independent"] = endings.all(func(f): return f == endings[0])
		observed.append({"actor_id":id,"frames":seen.keys(),"fps":visual.walk_fps,"endings":endings})
	var legacy_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/manifest-v03.json"))
	var fallback = load("res://scripts/presentation/actor_visual.gd").new()
	game.actors[0].add_child(fallback)
	fallback.configure(game.actors[0],game,legacy_manifest.actors[0],game.presentation.skill_icons,game.presentation.font)
	game.actors[0].moved_this_frame = true
	fallback.tick_visual(0.01)
	var legacy_first: String = fallback.frame_name
	fallback.tick_visual(0.32)
	checks.legacy_two_frame_fallback = fallback.walk_frames.is_empty() and legacy_first == "walk_a" and fallback.frame_name == "walk_b"
	fallback.free()
	# Reload restores idle; actual gameplay then supplies all walk state flags.
	game.load_room("r04",["chat","lockpick","strong"],27)
	checks.reload_idle = game.presentation.visuals.all(func(v): return v.frame_name == "idle")
	game.actors[0].position = Vector2(540,970)
	game.map_camera.locate_selected()
	game.set_process(true)
	game.command_move(0,Vector2(540,1320))
	var moving_frames := {}
	var guard_frames := {}
	for i in range(120):
		await frame()
		if game.actors[0].moved_this_frame:
			moving_frames[game.presentation.visuals[0].frame_name] = true
		if game.guard.moved_this_frame:
			guard_frames[game.presentation.visuals[3].frame_name] = true
	checks.actual_move_animates = moving_frames.size() >= 4
	checks.actual_patrol_animates = guard_frames.size() >= 4
	checks.actual_follow_continues = game.map_camera.following and game.map_camera.position.y > 540
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","strong"],27)
	game.set_process(false)
	game.actors[0].moved_this_frame = true
	game.presentation.visuals[0].tick_visual(0.26)
	game.presentation.lighting.set_period("day")
	await frame()
	var suffix := "%dx%d"%[root.size.x,root.size.y]
	root.get_texture().get_image().save_png("res://docs/tests/p27-day-%s.png"%suffix)
	game.presentation.lighting.set_period("night")
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p27-night-%s.png"%suffix)
	var passed: bool = checks.values().all(func(v): return v == true)
	var report := {"passed":passed,"checks":checks,"observed":observed,"actual_actor_frames":moving_frames.keys(),"actual_guard_frames":guard_frames.keys(),"scope":"Native GPU frames and actual movement/guard; separate deterministic playback fixtures test clock/stop/pause/flip. No human or Android/iOS verdict."}
	FileAccess.open("res://docs/tests/p27-walk-%s.json"%suffix,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game.presentation.stop_all()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
