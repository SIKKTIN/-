extends SceneTree
func _initialize() -> void:call_deferred("open_game")
func open_game() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://drying-yard-v1-preview.cfg")
	root.size=Vector2i(1440,900)
	root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	current_scene=game
	await process_frame
	game.actors[0].position=Vector2(1460,2910)
	game.orders.stop(0)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(1500,2860))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	root.title="监狱风云 · 食堂南侧晾晒区实机预览"
	game.show_status("晾晒区已接入，可沿中央道路往返食堂和洗衣室。")
	print("DRYING_YARD_GAME_READY")
