extends SceneTree

const OUT := "res://docs/devlog/02/images/"
var game
var report: Array = []

func _initialize():
	create_timer(90).timeout.connect(func(): quit(124))
	call_deferred("run")

func frame():
	await process_frame
	await RenderingServer.frame_post_draw

func shot(filename: String, point: Vector2, zoom_value: float, viewport_size: Vector2i, actor_point: Vector2):
	root.size = viewport_size
	root.content_scale_size = viewport_size
	game.actors[0].position = actor_point
	game.map_camera.zoom = Vector2.ONE*zoom_value
	game.map_camera.enabled_for_room = true
	game.map_camera.center_on(point)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	for warning in game.presentation.guard_warnings.values(): warning.hide()
	game.get_node("HUD").hide()
	game.queue_redraw()
	await frame()
	await frame()
	var output: String = OUT+filename
	var error := root.get_texture().get_image().save_png(output)
	report.append({"file":filename,"saved":error==OK,"camera_center":[point.x,point.y],"zoom":zoom_value,"viewport":[viewport_size.x,viewport_size.y],"source":"native Godot framebuffer; HUD and guard vision overlay hidden for editorial capture"})

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://devlog02-frames.cfg")
	OS.set_environment("ESCAPE_MENU_SETTINGS_PATH","user://devlog02-menu.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://devlog02-developer.cfg")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1600,960)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.tutorial.set_process(false)
	game.tutorial.cancel()
	await shot("01-map-overview.png",Vector2(3000,2250),0.4,Vector2i(2400,1800),Vector2(740,1700))
	await shot("02-living-area.png",Vector2(1750,2300),0.8,Vector2i(1600,960),Vector2(1520,2190))
	await shot("03-workshop.png",Vector2(3100,1350),0.8,Vector2i(1600,960),Vector2(2850,1430))
	await shot("04-yard.png",Vector2(2120,520),0.8,Vector2i(1600,960),Vector2(2650,520))
	FileAccess.open("res://docs/devlog/02/capture-report.json",FileAccess.WRITE).store_string(JSON.stringify({"map_id":game.room_id,"bounds":[game.world.bounds.size.x,game.world.bounds.size.y],"images":report},"\t"))
	print("DEVLOG02_CAPTURE ",JSON.stringify(report))
	quit(0)
