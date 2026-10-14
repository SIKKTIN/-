extends SceneTree
func _initialize(): call_deferred("play")
func play():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-door-exterior-play.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await process_frame; await process_frame
	var gate: Dictionary=game.world.access_by_id("workshop-entry")
	game.actors[0].position=Vector2(gate.rect.get_center().x+65,gate.rect.end.y+55)
	game.actors[0].immune_until=game.elapsed+60
	game.orders.stop(0); game.routines.take_control(0)
	game.map_camera.center_on(game.actors[0].position); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	root.title="监狱风云 · 车间门外空气墙修复试玩"
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/workshop-one-restoration/door-v2/exterior-fixed.png")
