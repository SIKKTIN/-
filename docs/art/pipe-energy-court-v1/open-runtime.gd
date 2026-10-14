extends SceneTree
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://energy-court-v1-runtime.cfg")
	root.size=Vector2i(1440,960)
	root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	current_scene=game
	await process_frame
	game.orders.clear()
	game.actors[0].position=Vector2(3100,3800)
	game.actors[0].immune_until=game.elapsed+600
	game.room_visibility.tick(0,true)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.42,.42)
	game.map_camera.position=Vector2(3600,2980)-Vector2(root.size)/.84
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	root.title="监狱风云 · 方案七管线能源庭院实机试玩"
	print("ENERGY_COURT_RUNTIME_READY room=",game.room_visibility.active_id)
