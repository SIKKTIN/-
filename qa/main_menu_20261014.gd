extends SceneTree

const OUT := "res://docs/tests/main-menu-20261014/"
var checks := {}
var menu
var native := false

func _initialize():
	create_timer(100).timeout.connect(func(): quit(124))
	OS.set_environment("ESCAPE_MENU_SETTINGS_PATH", "user://main-menu-qa.cfg")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH", "user://main-menu-frames-qa.cfg")
	OS.set_environment("ESCAPE_TUTORIAL_MODE", "off")
	call_deferred("run")

func check(label: String, ok: bool):
	checks[label] = ok
	if not ok: print("FAIL: ", label)

func frame():
	await process_frame
	if native: await RenderingServer.frame_post_draw
	else: await process_frame

func click(button: Button):
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frame()

func shot(id: String):
	if native: root.get_texture().get_image().save_png(OUT+id+".png")

func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1200, 720)
	root.content_scale_size = root.size
	var preferences = load("res://scripts/core/menu_preferences.gd").new()
	preferences.preference_path = "user://main-menu-qa.cfg"
	preferences.volume = 1.0
	preferences.fullscreen = false
	preferences.save()
	check("default startup is main menu", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn")
	check("main menu instantiates", change_scene_to_file("res://scenes/main_menu.tscn") == OK)
	await frame()
	menu = current_scene
	check("art is imported and available", menu.BACKGROUND.get_width() > 1000)
	check("continue unavailable without save", menu.continue_button.disabled)
	check("start initially focused", menu.start_button.has_focus())
	check("primary focused text stays ivory", menu.start_button.get_theme_color("font_focus_color").is_equal_approx(Color("f7f2e7")))
	for viewport_size in [Vector2i(1200,720), Vector2i(960,540), Vector2i(1920,1080), Vector2i(960,720)]:
		root.size = viewport_size
		root.content_scale_size = root.size
		await frame()
		var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
		var valid := true
		for button in [menu.continue_button,menu.start_button,menu.settings_button,menu.quit_button,menu.help_button,menu.credits_button]:
			valid = valid and screen.encloses(button.get_global_rect())
		check("all controls fit "+str(viewport_size), valid)
		check("buttons remain on right "+str(viewport_size), menu.start_button.get_global_rect().position.x > viewport_size.x*.5)
		await shot("menu-"+str(viewport_size.x)+"x"+str(viewport_size.y))
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	await frame()
	await click(menu.settings_button)
	check("settings mouse click opens modal", menu.modal_layer.visible and menu.modal_title.text == "游戏设置")
	check("modal excludes background keyboard navigation", menu.start_button.focus_mode == Control.FOCUS_NONE)
	menu.frame_picker.select(1)
	menu.frame_picker.item_selected.emit(1)
	check("90 fps preset applied", Engine.max_fps == 90)
	var frames = load("res://scripts/core/frame_settings.gd").new()
	frames.configure()
	check("fps preset persists", frames.target_fps == 90)
	menu.volume_slider.value = 0
	check("zero volume mutes master", AudioServer.is_bus_mute(0))
	menu.volume_slider.value = 65
	check("volume applies and unmutes master", not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.65)<.001)
	preferences.configure()
	check("volume persists", is_equal_approx(preferences.volume,.65))
	await frame()
	await shot("settings")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await frame()
	check("escape dismisses settings", not menu.modal_layer.visible)
	check("menu focus restored", menu.start_button.focus_mode == Control.FOCUS_ALL)
	# Real keyboard activation must open a dialog too.
	menu.help_button.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	enter = enter.duplicate()
	enter.pressed = false
	root.push_input(enter)
	await frame()
	check("keyboard enter activates focused menu control", menu.modal_layer.visible and menu.modal_title.text == "操作说明")
	menu.close_dialog()
	await click(menu.help_button)
	check("instructions mouse click opens", menu.modal_layer.visible and menu.modal_title.text == "操作说明")
	await shot("instructions")
	await click(menu.modal_close)
	check("dialog return button works", not menu.modal_layer.visible)
	await click(menu.credits_button)
	check("credits opens", menu.modal_layer.visible and menu.modal_title.text == "制作人员")
	await click(menu.modal_close)
	if not native:
		menu.show_settings()
		menu.fullscreen_toggle.button_pressed = true
		preferences.configure()
		check("fullscreen choice persists", preferences.fullscreen)
		menu.fullscreen_toggle.button_pressed = false
		menu.close_dialog()
	# The actual button/input pipeline must reach loading and then gameplay.
	await click(menu.start_button)
	check("start button enters loading", current_scene != null and current_scene.name == "Loading")
	var deadline := Time.get_ticks_msec()+60000
	while (current_scene == null or current_scene.name != "EscapeGame") and Time.get_ticks_msec()<deadline:
		await frame()
	check("loading reaches game", current_scene != null and current_scene.name == "EscapeGame")
	if current_scene != null and current_scene.name == "EscapeGame":
		current_scene.set_process(false)
		check("R04 selected", current_scene.room_id == "r04")
		check("camera keeps zoom 0.8", current_scene.map_camera.zoom.is_equal_approx(Vector2(.8,.8)))
		check("audio preference survives game startup", absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.65)<.001)
		await frame()
		await shot("entered-game")
	var failed: Array = checks.keys().filter(func(key): return not checks[key])
	FileAccess.open(OUT+("native" if native else "headless")+"-checks.json", FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"))
	print("Main menu: ", checks.size(), " checks; failures=", failed)
	quit(0 if failed.is_empty() else 1)
