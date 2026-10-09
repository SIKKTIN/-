extends "res://qa/p101_npc_responses.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p101-preview.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p101-preview-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	reset("backpack",740)
	game.guard.position = Vector2(1120,1300)
	game.room_visibility.tick(1,true)
	var target: Dictionary = game.dialogue.find_target("guard:patrol")
	check("preview_opens_real_guard_conversation",approach(target) and game.dialogue.open(str(target.id)))
	for dims in [Vector2i(1200,720),Vector2i(960,540)]:
		root.size = dims
		root.content_scale_size = dims
		await frame()
		game.fullscreen_ui.layout()
		game.map_camera.center_on((game.actors[0].position+game.guard.position)/2)
		game.presentation.tick(0)
		game.fullscreen_ui.refresh()
		game.dialogue.layout()
		await frame()
		check("preview_layout_"+str(dims.x),fits())
		await shot("responses-preview-"+str(dims.x))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p101-response-preview.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
	quit(0 if failed.is_empty() else 1)
