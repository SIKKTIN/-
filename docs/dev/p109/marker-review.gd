extends SceneTree
var game
func _initialize(): call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p109-marker.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.actors[0].position=Vector2(428,1488)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(game.actors[0].position-Vector2(0,180))
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p109/feet-marker-runtime.png")
	quit()
