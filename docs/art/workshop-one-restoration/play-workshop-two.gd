extends SceneTree
func _initialize():call_deferred("open")
func open():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-two-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://workshop-two-playtest-buttons.cfg")
	root.size=Vector2i(1280,840)
	root.content_scale_size=Vector2i(1600,1050)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.title="监狱风云 · 一号车间空间与摆件修订试玩"
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	var area:Rect2=game.workshop.area
	game.actors[0].position=area.position+Vector2(580,460)
	game.actors[0].immune_until=game.elapsed+45
	game.workshop.overseer.position=area.position+Vector2(580,290)
	game.orders.stop(0);game.routines.take_control(0)
	game.map_camera.center_on(area.get_center()+Vector2(0,-20));game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	game.show_status("一号车间：靠近柜架按 E 搜索；劳动时关闭两处门禁，午休开放。",10)
