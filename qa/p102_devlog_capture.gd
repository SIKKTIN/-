extends "res://qa/p101_npc_responses.gd"

const OUTPUT := "res://docs/devlog/01/images/"

func save_image(filename: String):
	game.fullscreen_ui.refresh()
	game.fullscreen_ui.fps_badge.hide()
	game.fullscreen_ui.toast.hide()
	game.presentation.tick(0)
	await frame()
	await frame()
	root.get_texture().get_image().save_png(OUTPUT+filename)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","on")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://p102-devlog.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p102-devlog-layout.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.tutorial.set_process(false)
	game.reset_round(["backpack","lockpick","chat"],72)
	check("game_renamed",ProjectSettings.get_setting("application/config/name")=="监狱风云")
	for i in range(240):
		game.tutorial._process(0.05)
		game._process(0.05)
		if game.tutorial.dialogue_ready: break
	game.tutorial.text_revealed = 999
	game.tutorial._refresh()
	check("tutorial_has_real_presenter",game.tutorial.active and game.tutorial.speech.visible)
	await save_image("01-intake-day.png")
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	reset("backpack",480)
	game.tutorial.cancel()
	game.actors[0].position = game.routines._target(0,"work")
	game.routines.take_control(0)
	game.orders.stop(0)
	check("real_work_starts",game.workshop.start_work(0))
	for i in range(15): game._process(0.05)
	game.map_camera.center_on(game.actors[0].position+Vector2(100,40))
	game.room_visibility.tick(1,true)
	await save_image("02-workshop.png")
	reset("backpack",740)
	game.guard.position = Vector2(1120,1300)
	game.room_visibility.tick(1,true)
	var target: Dictionary = game.dialogue.find_target("guard:patrol")
	check("real_conversation_opens",approach(target) and game.dialogue.open(str(target.id)))
	game.dialogue.layout()
	await save_image("03-conversation.png")
	game.dialogue.close()
	for definition in ["lock_tool","door_key","scrap"]:
		var item: String = game.inventory.add_ground(definition,game.actors[0].position)
		check("inventory_pickup_"+definition,game.inventory.try_pickup(0,item).ok)
	game.inventory_panel._select(0)
	game.fullscreen_ui.bag_open = true
	check("inventory_has_three_real_items",game.inventory.items(0).size()==3)
	await save_image("04-inventory.png")
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/devlog/01/capture-report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"total":checks.size()},"\t"))
	quit(0 if failed.is_empty() else 1)
