extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://keycards-v1-preview.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04";root.add_child(game);current_scene=game
	await process_frame
	game.orders.clear()
	game.fullscreen_ui.bag_open=true
	game.fullscreen_ui.inventory_drawer.select_category("document")
	game.inventory_panel.selected_item=game.keycards.matching("dorm-0")
	game.fullscreen_ui.refresh_inventory()
	root.title="监狱风云 · 房卡与门禁实机"
	print("KEYCARD_GAME_READY starter=D-03+daily rooms=",game.keycards.room_by_id.size()," credentials=",game.inventory.items(0).map(func(id):return game.inventory.item_name(str(id))))
