extends SceneTree

var game
var checks := {}
var screenshots: Array = []
var suffix: String

func _initialize() -> void:
	call_deferred("_run")

func capture(name: String) -> void:
	game._update_ui()
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var path := "res://docs/tests/p12-%s-%s.png" % [name,suffix]
	picture.save_png(path)
	screenshots.append(path)
	checks.actual_window_size = picture.get_size() == root.size

func _run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var p = game.presentation
	checks.active_v02 = p.profile_id == "v02"
	checks.body_sizes = p.visuals[0].definition.world_height == 55 and p.visuals[3].definition.world_height == 62
	checks.all_scene_textures_loaded = game.floor_texture != null and game.world.art_textures.values().all(func(t): return t != null)
	checks.fixed_view_radius = game.guard.VIEW_RADIUS == 110
	var controls = game.get_node("HUD/ControlHint")
	checks.fixed_controls_fit_canvas = controls.position.y+controls.get_minimum_size().y <= 720
	checks.skill_explanation_separate_from_controls = game.hint_label.max_lines_visible == 4 and not game.hint_label.text.contains("R 重抽重开")
	checks.layers_ground_before_body_before_information = p.scene_layers[0].z_index < 114 and p.scene_layers[1].z_index > 674
	for room in ["r01","r02"]:
		game.load_room(room,["chat","lockpick","strong"],33)
		await capture(room+"-start")
		game.actors[0].position = Vector2(620,215)
		game.guard.position = Vector2(690,250)
		game.select_actor(0)
		checks[room+"_long_chat_description_available"] = game.skills.target_reason(game.actors[0]) == ""
		await capture(room+"-chat-ready")
		var wall: Rect2 = game.world.walls[2]
		game.actors[0].position = Vector2(wall.get_center().x,wall.position.y-19)
		game.actors[1].position = Vector2(wall.get_center().x-35,wall.end.y+19)
		game.actors[2].position = Vector2(game.world.door.position.x-27,game.world.door.get_center().y)
		game.actors[0].facing = Vector2.LEFT
		game.actors[1].facing = Vector2.RIGHT
		game.select_actor(0)
		game.guard.position = Vector2(wall.position.x-60,wall.get_center().y)
		game.guard.facing = Vector2.RIGHT
		p.tick(0)
		checks[room+"_occlusion_positions_valid"] = game.world.can_place_circle(game.actors[0].position,17,game.actors[0]) and game.world.can_place_circle(game.actors[1].position,17,game.actors[1])
		checks[room+"_body_front_and_back"] = game.actors[0].z_index < p.volumes[2].z_index and game.actors[1].z_index > p.volumes[2].z_index
		checks[room+"_flip_keeps_foot_origin"] = p.visuals[0].flip_h and not p.visuals[1].flip_h and p.visuals[0].position == Vector2.ZERO
		checks[room+"_true_view_clips_wall"] = not game.guard.sees(wall.get_center()+Vector2(wall.size.x,0))
		await capture(room+"-occlusion-closed")
		game.select_actor(2)
		game.skills.toggle(2)
		# This actor is strong; use the real lockpick actor for the progress view.
		game.actors[2].position = Vector2(185,510)
		game.actors[1].position = Vector2(game.world.door.position.x-27,game.world.door.get_center().y)
		game.skills.toggle(1)
		game.skills.tick(1.6)
		await capture(room+"-lock-progress")
		game.skills.tick(2.5)
		checks[room+"_real_door_open"] = game.world.door_open and game.world.can_place_circle(game.world.door.get_center(),17,null,false)
		var before: Rect2 = game.world.crate
		game.actors[2].position = before.position+Vector2(-18,before.size.y*0.5)
		game.world.move_actor(game.actors[2],Vector2(10,0),true,10)
		p.tick(0)
		var crate_visual = p.volumes.back()
		checks[room+"_crate_moves_visual_with_logic"] = game.world.crate.position.x > before.position.x and crate_visual.display_rect.position == game.world.crate.position-Vector2(0,20) and crate_visual.display_rect.size == game.world.crate.size+Vector2(0,20)
		checks[room+"_door_ground_registration"] = p.volumes[3].display_rect.position == game.world.door.position-Vector2(0,20) and p.volumes[3].display_rect.size == Vector2(22,140)
		await capture(room+"-open-pushed")
	var report := {"passed":checks.values().all(func(v):return v == true),"checks":checks,"screenshots":screenshots,"presentation":p.snapshot(),"window":[root.size.x,root.size.y]}
	var file := FileAccess.open("res://docs/tests/p12-perspective-%s.json" % suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P12_PERSPECTIVE ",JSON.stringify(report.checks)," passed=",report.passed)
	p.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit(0 if report.passed else 1)
