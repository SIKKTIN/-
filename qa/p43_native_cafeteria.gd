extends SceneTree

var game
var checks := {}
var prefix := "p43-native-"

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func frame() -> void:
	root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw

func press(control: Control) -> void:
	await frame()
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform()*control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await frame()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frame()

func shot(name: String) -> void:
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+name+".png")

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.attributes.account_clock = game.schedule.clock_elapsed
	game.schedule.tick(false)
	game.routines.tick()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var width := int(args[0]) if not args.is_empty() else 1200
	var height := int(args[1]) if args.size() > 1 else roundi(width*0.6)
	root.content_scale_size = Vector2i(width,height)
	root.size = root.content_scale_size
	await frame()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],43)
	prefix += str(int(game.get_viewport_rect().size.x))+"-"
	checks.morning_paused = paused and game.routine_panel.panel.visible
	checks.meal_choice_exists = game.routine_panel.picker_options.any(func(b): return b.kind == "meal")
	for id in range(3):
		await press(game.routine_panel.selectors[1][id])
		checks["touch_meal_enabled_"+str(id)] = game.routine_panel.picker.visible and not game.routine_panel.picker_options[4].disabled
		checks["picker_inside_"+str(id)] = game.routine_panel.panel.get_global_rect().encloses(game.routine_panel.picker.get_global_rect())
		checks["picker_above_footer_"+str(id)] = game.routine_panel.picker.position.y+game.routine_panel.picker.size.y <= game.routine_panel.apply_button.position.y-4
		if id == 0:
			await shot("meal-picker")
		await press(game.routine_panel.picker_options[4])
	checks.touch_meal_draft = game.routine_panel.draft.all(func(row): return row[1] == "meal")
	await shot("meal-planner")
	await press(game.routine_panel.apply_button)
	checks.apply_unpauses = not paused and game.routines.plans.all(func(row): return row[1] == "meal")
	game.schedule.set_time_speed(0)
	minute(720)
	game.fullscreen_ui.minimap_collapsed = true
	game.fullscreen_ui.layout()
	var arrived := false
	for index in range(2400):
		game._process(1.0/60)
		if range(3).all(func(id): return game.routines.is_eating(id)):
			arrived = true
			break
	checks.real_all_eating = arrived
	checks.new_textures_loaded = ["cafeteria_counter","cafeteria_return","cafeteria_queue","cafeteria_tray"].all(func(id): return game.world.art_textures.has(id) and game.world.art_textures[id] != null)
	checks.has_mipmaps = ["cafeteria_counter","cafeteria_return","cafeteria_queue","cafeteria_tray"].all(func(id): return game.world.art_textures.has(id) and game.world.art_textures[id].get_image().has_mipmaps())
	checks.trays_above_tables = game.presentation.volumes.filter(func(v): return v.kind == "fixture" and v.prop_id() == "cafeteria_tray").all(func(v): return v.z_index > (1695 if v.footprint.position.y > 1500 else 1395))
	game.map_camera.center_on(Vector2(1240,1300))
	await shot("canteen-upper")
	game.map_camera.center_on(Vector2(1240,1530))
	await shot("canteen-lower")
	game.schedule.set_time_speed(1)
	game.attributes.values[0].fullness = 30
	game.attributes.values[0].stamina = 30
	game._process(6.25)
	checks.native_real_food = game.attributes.values[0].fullness > 50 and game.attributes.values[0].stamina > 45
	checks.day_no_arrest = game.captures == 0
	game.map_camera.center_on(Vector2(1240,1300))
	await shot("eating")
	await press(game.cards[0])
	game.stop_selected()
	game.actors[0].position = Vector2(1080,1240) # Nearby interaction fixture.
	game.map_camera.center_on(Vector2(1220,1200))
	game.presentation.tick(0)
	checks.manual_pickup_prompt = game.presentation.interaction.extras.has("meal:cafeteria") and game.presentation.interaction.extras["meal:cafeteria"].visible
	if checks.manual_pickup_prompt:
		await press(game.presentation.interaction.extras["meal:cafeteria"])
	checks.manual_pickup_starts = game.routines.records.has(0) and game.routines.records[0].kind == "meal" and not game.routines.manual.has(0)
	checks.meal_not_backpack = game.inventory.items(0).is_empty()
	game.routine_panel.open()
	game.routine_panel.open_picker(0,2)
	checks.outside_lunch_disabled = game.routine_panel.picker_options[4].disabled
	game.routine_panel.close()
	minute(840)
	game.presentation.tick(0)
	checks.outside_lunch_hidden = not game.presentation.interaction.extras["meal:cafeteria"].visible and game.routines.meal_reason(0) != ""
	minute(1200)
	game.map_camera.center_on(Vector2(1240,1300))
	game.presentation.tick(0)
	checks.night_lighting = game.presentation.lighting.period == "night"
	await shot("canteen-night")
	game.load_room("r03",["chat","lockpick","backpack"],43)
	game.routine_panel.open_picker(0,1)
	checks.legacy_picker_four_visible = game.routine_panel.picker_options.filter(func(b): return b.visible).size() == 4 and game.routine_panel.picker.size.y == 292
	game.routine_panel.close()
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/"+prefix+"qa.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Windows native rendered touch UI, real three-person meal paths. One nearby manual-prompt position fixture. No Android/iOS or human test."},"\t")+"\n")
	print("P43_NATIVE passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
