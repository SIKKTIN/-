extends SceneTree
const OUT := "res://docs/art/campus-expansion-v47/"
var game
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func shot(id: String, p: Vector2):
	game.actors[0].position=p
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(p-Vector2(0,180))
	game.presentation.tick(0)
	game._update_ui()
	await frame();await frame()
	root.get_texture().get_image().save_png(OUT+id+"-runtime.png")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p106-render.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide() # Offline stepped captures aren't an FPS sample.
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed=(1020-game.schedule.config.start_minutes)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.workshop.update_gate()
	game.room_access.tick()
	await shot("clinic",Vector2(1810,900))
	await shot("bath",Vector2(1250,920))
	await shot("yard",Vector2(2750,800))
	for id in ["office-entry","monitor-entry","tools-entry"]:game.world.set_access_closed(id,false)
	await shot("monitor",Vector2(4960,980))
	await shot("workshop-two",Vector2(2920,1900))
	await shot("repair",Vector2(3050,3880))
	print("Saved six actual gameplay area captures.")
	quit()
