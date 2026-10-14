extends "res://qa/p101_npc_responses.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p117-night-review.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.actors[0].position=Vector2(430,1500)
	game.guard.position=Vector2(610,1520)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(game.actors[0].position)
	game.presentation.lighting.set_period("night")
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p117/dorm-night.png")
	quit()
