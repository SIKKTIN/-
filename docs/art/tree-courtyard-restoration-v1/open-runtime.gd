extends SceneTree
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://tree-courtyard-runtime.cfg")
	root.size=Vector2i(1440,960)
	root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	current_scene=game
	await process_frame
	game.orders.clear()
	game.actors[0].position=Vector2(3590,2820)
	game.actors[0].immune_until=game.elapsed+600
	game.room_visibility.tick(0,true)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.56,.56)
	game.map_camera.position=Vector2(3570,2420)-Vector2(root.size)/1.12
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	root.title="监狱风云 · 自强树庭实机试玩"
	print("TREE_COURT_RUNTIME_READY outdoors=",game.room_visibility.active_id.is_empty())
