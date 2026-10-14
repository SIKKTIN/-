extends SceneTree
func _initialize():call_deferred("open")
func open():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://chess-v1-play.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://chess-v1-play-buttons.cfg")
	root.size=Vector2i(1400,950);root.content_scale_size=root.size
	root.title="监狱风云 · 棋牌活动室还原试玩"
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.schedule.clock_elapsed=(1080.0-480.0)/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(0);game.schedule.tick(false);game.room_access.tick()
	game.actors[0].position=Vector2(1330,645);game.actors[0].moved_this_frame=false
	game.room_visibility.tick(0,true);game.resident_staff.tick(0)
	game.map_camera.center_on(Vector2(1180,485));game.map_camera.force_update_scroll()
	await process_frame;game.presentation.tick(0);game._update_ui()
	game.show_status("棋牌活动室试玩：固定18:00，收纳柜可翻找；棋盘与纸牌为美术摆件。",12)
