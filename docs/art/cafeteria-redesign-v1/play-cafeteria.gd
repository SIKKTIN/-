extends SceneTree
func _initialize():call_deferred("open")
func open():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-redesign-play.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://cafeteria-redesign-play-buttons.cfg")
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	root.title="监狱风云 · 食堂概念还原试玩"
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.schedule.clock_elapsed=(750.0-480.0)/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(0);game.schedule.tick(false);game.room_access.tick()
	game.routines.tick()
	game.actors[0].position=Vector2(895,2860)
	game.actors[0].moved_this_frame=false
	game.room_visibility.tick(0,true);game.resident_staff.tick(0)
	game.map_camera.center_on(Vector2(1500,2780));game.map_camera.force_update_scroll()
	await process_frame
	game.presentation.tick(0);game._update_ui()
	game.show_status("食堂试玩：已固定12:30；走到配餐台前按E取餐，或出门检查屋顶。",12)
