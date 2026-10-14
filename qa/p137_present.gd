extends SceneTree
var game
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func stats(values: Array) -> Dictionary:
	var a:=values.duplicate()
	a.sort()
	return {"mean":values.reduce(func(x,y):return x+y,0.0)/values.size(),"p95":a[int(a.size()*0.95)],"p99":a[int(a.size()*0.99)],"max":a.back()}
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p137-present-frame.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p137-present-dev.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	root.title="监狱风云 · 呈现对照测试"
	root.unfocusable=true
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.actors[0].position=Vector2(1640,1750)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	game.presentation.tick(0)
	var cases: Dictionary={}
	for mode in [DisplayServer.VSYNC_DISABLED,DisplayServer.VSYNC_ENABLED,DisplayServer.VSYNC_DISABLED]:
		DisplayServer.window_set_vsync_mode(mode)
		for i in range(90):await frame()
		var values: Array=[]
		var last:=Time.get_ticks_usec()
		for i in range(420):
			await frame()
			var now:=Time.get_ticks_usec()
			values.append((now-last)/1000.0)
			last=now
		var name: String="mode_%d_pass_%d" % [mode,cases.size()]
		cases[name]=stats(values)
		print(name+" "+JSON.stringify(cases[name]))
	FileAccess.open("res://docs/dev/p137/present.json",FileAccess.WRITE).store_string(JSON.stringify({"frozen_scene":true,"fps_cap":Engine.max_fps,"refresh_hz":DisplayServer.screen_get_refresh_rate(root.current_screen),"driver":RenderingServer.get_current_rendering_driver_name(),"cases":cases},"\t"))
	game.queue_free()
	await frame()
	await frame()
	quit()
