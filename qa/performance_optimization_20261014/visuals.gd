extends SceneTree
const OUT="res://docs/dev/performance-optimization-2026-10-14/"
var game
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://performance-visuals-qa.cfg")
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	var mode: String="source" if OS.get_environment("ESCAPE_SOURCE_TEXTURES")=="1" else "baked"
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frame();game.set_process(false);game.fullscreen_ui.set_process(false)
	game.load_room("r04",["chat","chat","backpack"],136)
	game.schedule.set_time_speed(0)
	var points: Dictionary={"dorm":game.actors[0].home,"workshop":Vector2(1500,1380),"cafeteria":Vector2(1600,2250),"clinic":Vector2(1780,480),"courtyard":Vector2(3180,2440),"bath":Vector2(1880,3700)}
	var registered: Dictionary={}
	for zoom in [1.0,1.8]:
		game.map_camera.zoom=Vector2.ONE*zoom
		for name in points:
			game.actors[0].position=points[name]
			game.map_camera.center_on(points[name]);game.map_camera.following=false
			game.room_visibility.tick(0,true);game.presentation.tick(0);game.fullscreen_ui.refresh()
			for v in game.presentation.visuals:v.tick_visual(0)
			await frame();await frame()
			root.get_texture().get_image().save_png(OUT+mode+"-"+name+"-"+str(zoom)+".png")
			registered[name+str(zoom)]={"player_destination":str(game.presentation.visuals[0].destination),"doors":game.room_visibility.doorways.doors.map(func(d):return str(d.visual_rect))}
	FileAccess.open(OUT+mode+"-registration.json",FileAccess.WRITE).store_string(JSON.stringify(registered,"\t"))
	print("VISUAL_DONE "+mode);game.queue_free();await frame();quit()
