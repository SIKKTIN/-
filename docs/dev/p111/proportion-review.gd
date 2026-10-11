extends "res://qa/p101_npc_responses.gd"

func shot(label: String):
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/dev/p111/"+label+".png")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p111-proportions.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.actors[0].position=Vector2(365,1480)
	game.guard.position=Vector2(730,1640)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(game.actors[0].position)
	await shot("dorm-proportions")
	game.actors[0].position=game.routines._target(0,"work")
	game.guard.position=game.actors[0].position+Vector2(100,80)
	game.room_visibility.tick(1,true)
	game.map_camera.center_on(game.actors[0].position)
	await shot("workshop-proportions")
	print("Captured actual dorm and workshop human/furniture proportions.")
	quit()
