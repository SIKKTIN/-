extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	root.size = Vector2i(1200,800)
	root.content_scale_size = root.size
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame; await process_frame
	root.title = "监狱风云 · 宿舍厚门与开关交互试玩"
	var door = game.room_visibility.doorways.by_id("dorm-0")
	game.actors[0].position = Vector2(door.visual_rect.position.x-65,door.visual_rect.end.y-54)
	game.map_camera.following = false
	game.map_camera.zoom = Vector2.ONE*1.35
	game.map_camera.position = door.visual_rect.get_center()+Vector2(-220,-20)-Vector2(root.size)/game.map_camera.zoom/2
	game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
