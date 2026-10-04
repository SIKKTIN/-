extends SceneTree

var game
var checks := {}
var metrics := {}
var pictures: Array = []
var suffix: String

func _initialize() -> void:
	call_deferred("run")

func frame(name: String = "") -> Image:
	game._update_ui()
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if name != "":
		var path := "res://docs/tests/p20-regression-%s-%s.png" % [name,suffix]
		image.save_png(path)
		pictures.append(path)
	return image

func luminance(image: Image, point: Vector2) -> float:
	var pixel: Vector2 = root.get_final_transform()*root.get_canvas_transform()*point
	var color := image.get_pixel(roundi(pixel.x),roundi(pixel.y))
	return color.r*0.2126+color.g*0.7152+color.b*0.0722

func run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var lighting = game.presentation.lighting
	var prompt = game.presentation.interaction
	checks.real_flashlight = lighting.guard_light is PointLight2D and lighting.guard_light.shadow_enabled
	checks.old_global_skill_button_hidden = not game.skill_button.visible
	for room in ["r01","r02"]:
		game.load_room(room,["chat","lockpick","strong"],15)
		game.elapsed = 3
		game.guard.position = Vector2(875,150)
		game.guard.facing = Vector2.DOWN
		lighting.set_period("day")
		checks[room+"_day_sees_180"] = game.guard.sees(Vector2(875,330)) and game.guard.view_radius() == 210
		await frame(room+"-day-beam")
		lighting.set_period("night")
		checks[room+"_night_not_180"] = not game.guard.sees(Vector2(875,330)) and game.guard.view_radius() == 155
		await frame(room+"-night-beam")
		checks[room+"_beam_scale_matches_detection"] = is_equal_approx(lighting.guard_light.texture_scale*128,game.guard.view_radius()) and is_equal_approx(lighting.guard_light.rotation,game.guard.facing.angle())
		game.actors[0].position = Vector2(875,220)
		game.guard.tick(0)
		checks[room+"_immediate_chase"] = game.guard.state == "chasing" and game.guard.target_id == 0
		game.actors[0].position = game.actors[0].home
		game.guard.tick(0.01)
		checks[room+"_safe_room_immediate_release"] = game.guard.state == "patrol" and game.guard.target_id == -1 and game.captures == 0
		game.world.open_door()
		game.guard.position = Vector2(game.world.guard_zone.position.x+20,395)
		game.guard.facing = Vector2.LEFT
		game.actors[0].position = Vector2(game.world.guard_zone.position.x-1,395)
		checks[room+"_safe_room_not_seen"] = not game.guard.sees(game.actors[0].position)
		game.guard.state = "chasing"
		game.guard.target_id = 0
		game.guard._capture_if_touching()
		checks[room+"_safe_room_not_captured"] = game.captures == 0
		checks[room+"_guard_path_rejects_safe_room"] = game.world.find_path(game.guard.position,game.actors[0].home,game.guard).is_empty()
		var before: Vector2 = game.guard.position
		game.world.move_actor(game.guard,Vector2(-100,0))
		checks[room+"_movement_cannot_cross_boundary"] = game.guard.movement_allowed(game.guard.position) and game.guard.position.x >= game.world.guard_zone.position.x+17
		game.actors[0].position = game.actors[0].home
		game.guard.reset_guard()
		var last_route: int = game.guard.route_index
		var transitions := 0
		var always_inside := true
		for tick in range(3600):
			game.elapsed += 1.0/60.0
			game.guard.tick(1.0/60.0)
			always_inside = always_inside and game.guard.movement_allowed(game.guard.position)
			if game.guard.route_index != last_route:
				transitions += 1
				last_route = game.guard.route_index
		metrics[room+"_patrol_transitions_60s"] = transitions
		checks[room+"_patrol_stable_in_zone"] = always_inside and transitions > 5
		# Real light pixels prove the beam stays out of the safe room.
		game.guard.position = Vector2(game.world.guard_zone.position.x+60,280)
		game.guard.facing = Vector2.LEFT
		for lamp in lighting.lamps:
			lamp.enabled = false
		var lit: Image = await frame()
		lighting.guard_light.enabled = false
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var dark := root.get_texture().get_image()
		var outside := Vector2(game.world.guard_zone.position.x-40,280)
		# Keep this floor probe clear of the unshaded 18..31px facing arrow.
		var inside := Vector2(game.world.guard_zone.position.x+20,280)
		var outside_gain := luminance(lit,outside)-luminance(dark,outside)
		var inside_gain := luminance(lit,inside)-luminance(dark,inside)
		metrics[room+"_safe_light_gain"] = outside_gain
		metrics[room+"_guard_light_gain"] = inside_gain
		checks[room+"_light_clips_safe_boundary"] = absf(outside_gain) < 0.015 and inside_gain > 0.1
		# Reset restores closed door and lamp configuration.
		game.load_room("r02" if room == "r01" else "r01",["chat","lockpick","strong"],15)
		game.load_room(room,["chat","lockpick","strong"],15)
		lighting.set_period("night")
		game.select_actor(1)
		prompt.refresh()
		checks[room+"_distant_icon_hidden"] = not prompt.button.visible
		game.actors[1].position = game.world.door.get_center()+Vector2(-38,0)
		await frame(room+"-lock-icon")
		checks[room+"_near_lock_icon"] = prompt.button.visible and prompt.kind == "lockpick"
		prompt.button.pressed.emit()
		checks[room+"_icon_starts_lock"] = game.skills.actions.has(1)
		game.select_actor(0)
		prompt.refresh()
		checks[room+"_switch_keeps_operator"] = game.skills.actions.has(1) and not prompt.button.visible
		game.select_actor(1)
		prompt.refresh()
		prompt.button.pressed.emit()
		checks[room+"_icon_stops_own_skill"] = not game.skills.actions.has(1)
		game.use_selected_skill()
		checks[room+"_e_starts_lock"] = game.skills.actions.has(1)
		game.skills.tick(4.1)
		prompt.refresh()
		checks[room+"_open_door_hides_icon"] = game.world.door_open and not prompt.button.visible
		game.guard.position = Vector2(750,230)
		game.actors[0].position = Vector2(680,230)
		game.guard.facing = Vector2.RIGHT
		game.select_actor(0)
		await frame(room+"-chat-icon")
		checks[room+"_near_chat_icon"] = prompt.button.visible and prompt.kind == "chat"
		prompt.button.pressed.emit()
		checks[room+"_icon_chats_with_guard"] = game.guard.state == "talking" and game.skills.actions.has(0)
		game.skills.cancel(0)
		game.guard.state = "chasing"
		prompt.refresh()
		checks[room+"_chasing_hides_chat_icon"] = not prompt.button.visible
		game.guard.reset_guard()
		game.actors[2].position = game.world.crate.position+Vector2(-18,game.world.crate.size.y/2)
		game.select_actor(2)
		await frame(room+"-push-icon")
		checks[room+"_near_push_icon"] = prompt.button.visible and prompt.kind == "strong"
		var box_before: Rect2 = game.world.crate
		prompt.button.pressed.emit()
		for tick in range(30):
			game.orders.tick(1.0/60.0)
		checks[room+"_click_really_pushes"] = game.world.crate.position.x > box_before.position.x
		game.actors[2].position = game.actors[2].home
		prompt.refresh()
		checks[room+"_leaving_hides_push_icon"] = not prompt.button.visible
	var report := {"passed":checks.values().all(func(value):return value == true),"checks":checks,"metrics":metrics,"screenshots":pictures,"window":[root.size.x,root.size.y]}
	var file := FileAccess.open("res://docs/tests/p20-regression-guard-interaction-%s.json" % suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P15 ",JSON.stringify(report))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if report.passed else 1)
