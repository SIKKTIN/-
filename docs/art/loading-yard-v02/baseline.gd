extends SceneTree
const OUT := "res://docs/art/loading-yard-v02/"
var game
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://loading-yard-qa.cfg")
	root.size=Vector2i(1000,2400)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	game.actors[0].position=Vector2(5450,2100)
	game.room_visibility.tick(0,true)
	game.map_camera.zoom=Vector2(.55,.55)
	game.map_camera.position=Vector2(5430,2150)-Vector2(root.size)/game.map_camera.zoom/2
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"runtime-before.png")
	var durations: Array=[]
	var start := Time.get_ticks_usec()
	for i in range(90):
		game.presentation.tick(0)
		durations.append(Time.get_ticks_usec()-start)
		start=Time.get_ticks_usec()
		await frame()
	var f=FileAccess.open(OUT+"baseline-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"viewport":[1000,2400],"zoom":.55,"frame_us":durations,"static_builds":game.presentation.scene_layers[0].static_ground.builds},"\t"))
	game.queue_free()
	await frame()
	quit()

