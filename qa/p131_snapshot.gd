extends "res://qa/p105_collision.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p131-snapshot.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	root.size=Vector2i(1200,960)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","chat","backpack"],131)
	game.world.admission_filter=Callable()
	game.actors[0].position=Vector2(510,3760)
	game.room_visibility.tick(0,true)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2.ONE
	game.map_camera.position=Vector2(0,3250)
	game.map_camera.force_update_scroll()
	game.get_node("HUD").hide()
	game.presentation.tick(0)
	await frame()
	await frame()
	var elapsed: Array=[]
	var cpu: Array=[]
	var draws: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in range(140):
		game.presentation.tick(0)
		await frame()
		var now:=Time.get_ticks_usec()
		if i>=40:
			elapsed.append(float(now-previous)/1000)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		previous=now
	var label: String=OS.get_cmdline_user_args()[0]
	root.get_texture().get_image().save_png("res://docs/dev/p131/"+label+".png")
	var mean:=func(a):return a.reduce(func(acc,value):return acc+value,0.0)/a.size()
	FileAccess.open("res://docs/dev/p131/"+label+"-performance.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":100,"frame_ms":mean.call(elapsed),"cpu_ms":mean.call(cpu),"draw_calls":mean.call(draws)},"\t"))
	if label=="after":
		root.size=Vector2i(1200,720)
		root.content_scale_size=root.size
		game.fullscreen_ui.layout()
		game.actors[0].position=Vector2(510,3780)
		game.room_visibility.tick(0,true)
		game.map_camera.zoom=Vector2.ONE
		game.map_camera.center_on(game.actors[0].position)
		game.get_node("HUD").show()
		game._update_ui()
		game.fullscreen_ui.fps_badge.hide()
		game.presentation.tick(0)
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p131/runtime.png")
		root.size=Vector2i(1200,900)
		root.content_scale_size=root.size
		game.get_node("HUD").hide()
		game.map_camera.zoom=Vector2.ONE*0.2
		game.map_camera.position=Vector2.ZERO
		game.map_camera.force_update_scroll()
		game.presentation.tick(0)
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p131/map-overview.png")
	quit()
