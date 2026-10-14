extends SceneTree
func _initialize(): call_deferred("play")
func play():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-door-v2-play.cfg")
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await process_frame; await process_frame
	var gate: Dictionary=game.world.access_by_id("workshop-entry")
	game.actors[0].position=Vector2(gate.rect.get_center().x,gate.rect.end.y+35)
	game.actors[0].immune_until=60
	game.orders.stop(0)
	game.routines.take_control(0)
	game.map_camera.center_on(game.actors[0].position+Vector2(0,-170))
	game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	root.title="监狱风云 · 统一车间钢门两态试玩"
