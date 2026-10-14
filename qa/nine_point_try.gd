extends SceneTree

# Interactive preview only: the 100 coins belong to this temporary game session.
func _initialize(): call_deferred("run")

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://nine-point-preview-dev.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://nine-point-preview-buttons.cfg")
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	DisplayServer.window_set_title("监狱风云 · 场景内九点与擦牌试玩")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.phase = "playing"
	game.fullscreen_ui.close_menu()
	game.schedule.panel.hide()
	game.developer_settings.panel.hide()
	game.dialogue.close()
	game.tutorial.cancel()
	game.schedule.clock_elapsed = (1030.0-game.schedule.config.start_minutes)/1440.0*game.schedule.day_seconds
	game.schedule.set_time_speed(1)
	game.schedule.tick(false)
	game.routines.tick()
	game.orders.clear()
	var tables: Array = game.nine_point.tables()
	if tables.is_empty(): push_error("Nine point preview: no card table"); return
	var area: Rect2 = tables[0].rect
	game.actors[game.PLAYER_ACTOR_ID].position = Vector2(area.get_center().x,area.end.y+49)
	game.room_visibility.tick(0)
	game.presentation.tick(0)
	game.inventory.wallet = 100
	game.nine_point.player_count = 4
	game.nine_point.amount = 10
	if not game.nine_point.open_table(str(tables[0].id)):
		push_error("Nine point preview could not open the table")
		return
	print("NINE_POINT_PREVIEW_READY: four players, 100 temporary coins, stake 10")
