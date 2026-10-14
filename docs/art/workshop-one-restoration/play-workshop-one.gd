extends SceneTree
func _initialize():call_deferred("open")
func open():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-one-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://workshop-one-playtest-buttons.cfg")
	root.size=Vector2i(1280,840)
	root.content_scale_size=Vector2i(1600,1050)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title="监狱风云 · 一号车间概念还原试玩"
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.actors[0].position=Vector2(1430,1820)
	game.actors[0].immune_until=game.elapsed+45
	game.workshop.overseer.position=Vector2(1430,1820)
	game.actors[0].position=Vector2(1430,1950)
	game.orders.stop(0);game.routines.take_control(0)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.map_camera.center_on(Vector2(1500,1760));game.map_camera.force_update_scroll()
	game.show_status("一号车间试玩：靠近柜架按 E 搜索；劳动时段门禁关闭，午休重新开放。",10)
