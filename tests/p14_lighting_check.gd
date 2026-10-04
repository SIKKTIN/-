extends SceneTree

var game
var checks := {}
var metrics := {}
var pictures: Array = []
var suffix: String

func _initialize() -> void:
	call_deferred("_run")

func frame() -> Image:
	game._update_ui()
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func sample(image: Image, point: Vector2, radius: int = 2) -> Color:
	var screen: Vector2 = root.get_final_transform()*root.get_canvas_transform()*point
	if screen.x < radius or screen.y < radius or screen.x >= image.get_width()-radius or screen.y >= image.get_height()-radius:
		checks.sample_coordinates_valid = false
		return Color.BLACK
	var result := Color(0,0,0,0)
	var count := 0
	for x in range(roundi(screen.x)-radius,roundi(screen.x)+radius+1):
		for y in range(roundi(screen.y)-radius,roundi(screen.y)+radius+1):
			result += image.get_pixel(x,y)
			count += 1
	return result/float(count)

func brightness(color: Color) -> float:
	return color.r*0.2126+color.g*0.7152+color.b*0.0722

func capture(name: String) -> Image:
	var image: Image = await frame()
	var path := "res://docs/tests/p14-%s-%s.png" % [name,suffix]
	image.save_png(path)
	pictures.append(path)
	checks.actual_size = image.get_size() == root.size
	return image

func _run() -> void:
	suffix = "%dx%d" % [root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var lighting = game.presentation.lighting
	checks.real_godot_lights = lighting.ambient is CanvasModulate and lighting.sun is DirectionalLight2D and lighting.lamps.all(func(l):return l is PointLight2D and l.shadow_enabled)
	checks.button_fits = lighting.toggle_button.position.y+lighting.toggle_button.size.y <= 62
	checks.hud_unmodulated = game.get_node("HUD") is CanvasLayer
	for room in ["r01","r02"]:
		game.load_room(room,["chat","lockpick","strong"],14)
		lighting.set_period("day")
		var day: Image = await capture(room+"-day")
		var before: Dictionary = game.snapshot()
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_N
		lighting._unhandled_input(key)
		var night: Image = await capture(room+"-night")
		checks[room+"_shortcut_toggles"] = lighting.period == "night"
		checks[room+"_toggle_preserves_game"] = game.snapshot() == before
		checks[room+"_lamps_from_room"] = lighting.lamps.size() == 3 and lighting.room_id == room
		checks[room+"_occluders_match_solids"] = lighting.occluders.size() == game.world.solid_rects().size()
		checks[room+"_paper_unchanged"] = sample(day,Vector2(15,350)).is_equal_approx(sample(night,Vector2(15,350)))
		checks[room+"_hud_card_unchanged"] = sample(day,Vector2(1100,165)).is_equal_approx(sample(night,Vector2(1100,165)))
		var day_dark := brightness(sample(day,Vector2(180,580)))
		var night_dark := brightness(sample(night,Vector2(180,580)))
		metrics[room+"_day_dark"] = day_dark
		metrics[room+"_night_dark"] = night_dark
		checks[room+"_day_night_different"] = day_dark-night_dark > 0.12 and night_dark > 0.10
		# Use one lamp at a fixed position to prove actual rendered light occlusion.
		for lamp in lighting.lamps:
			lamp.enabled = false
		var lamp = lighting.lamps[0]
		lamp.position = Vector2(game.world.door.position.x-80,game.world.door.get_center().y)
		lamp.energy = 1.1
		lamp.enabled = true
		var probe := Vector2(game.world.door.end.x+35,game.world.door.get_center().y)
		var closed: Image = await frame()
		var count: int = lighting.occluders.size()
		game.actors[1].position = game.world.door.get_center()+Vector2(-38,0)
		game.skills.toggle(1)
		game.skills.tick(4.1)
		var opened: Image = await frame()
		var gain := brightness(sample(opened,probe))-brightness(sample(closed,probe))
		metrics[room+"_door_light_gain"] = gain
		checks[room+"_door_shadow_removed"] = game.world.door_open and lighting.occluders.size() == count-1 and gain > 0.10
		# Real collision-valid push moves the crate out of this fixed light ray.
		lamp.position = Vector2(game.world.crate.get_center().x,game.world.crate.position.y-100)
		probe = Vector2(game.world.crate.get_center().x,game.world.crate.end.y+5)
		var box_before: Image = await frame()
		var pushed: bool = game.world._move_crate(Vector2(-120,0))
		var box_after: Image = await frame()
		gain = brightness(sample(box_after,probe))-brightness(sample(box_before,probe))
		metrics[room+"_crate_light_gain"] = gain
		checks[room+"_crate_shadow_moves"] = pushed and gain > 0.10 and lighting.obstacle_revision == game.world.obstacle_revision
		# A fixed wall also blocks real light; disable shadows only for the control image.
		var wall: Rect2 = game.world.walls[2]
		lamp.position = Vector2(wall.position.x-80,wall.get_center().y)
		probe = Vector2(wall.end.x+35,wall.get_center().y)
		var wall_shadow: Image = await frame()
		lamp.shadow_enabled = false
		var wall_no_shadow: Image = await frame()
		gain = brightness(sample(wall_no_shadow,probe))-brightness(sample(wall_shadow,probe))
		metrics[room+"_wall_light_gain"] = gain
		checks[room+"_wall_blocks_light"] = gain > 0.08
		lamp.shadow_enabled = true
		# Room reload restores fixture positions and closed-door/box occluders.
		game.load_room("r02" if room == "r01" else "r01",["chat","lockpick","strong"],14)
		game.presentation.tick(0)
		game.load_room(room,["chat","lockpick","strong"],14)
		game.presentation.tick(0)
		lighting.set_period("night")
		checks[room+"_reload_restores_geometry"] = lighting.occluders.size() == 5 and not game.world.door_open and game.world.crate == game.world.original_crate
		# Switching illumination while a colleague works keeps that action running.
		game.actors[1].position = game.world.door.get_center()+Vector2(-38,0)
		game.skills.toggle(1)
		game.skills.tick(0.8)
		var progress: float = game.world.lock_progress
		lighting.toggle_button.pressed.emit()
		checks[room+"_button_keeps_action"] = lighting.period == "day" and game.skills.actions.has(1) and game.world.lock_progress == progress
		game.select_actor(0)
		checks[room+"_independent_selection"] = game.skills.actions.has(1) and game.select_at(game.actors[0].position-Vector2(0,45))
		game.command_move(0,game.actors[0].position+Vector2(80,0))
		checks[room+"_rts_order_keeps_colleague"] = game.orders.active.has(0) and game.skills.actions.has(1)
		game.actors[0].facing = Vector2.LEFT
		game.presentation.tick(0)
		checks[room+"_left_facing"] = game.presentation.visuals[0].flip_h
	var report := {"passed":checks.values().all(func(v):return v == true),"checks":checks,"metrics":metrics,"screenshots":pictures,"lighting":lighting.snapshot(),"window":[root.size.x,root.size.y]}
	var file := FileAccess.open("res://docs/tests/p14-lighting-%s.json" % suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P14_LIGHTING ",JSON.stringify(checks)," metrics=",JSON.stringify(metrics))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if report.passed else 1)
