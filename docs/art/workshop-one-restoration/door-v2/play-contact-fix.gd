extends SceneTree
func _initialize(): call_deferred("play")
func play():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-door-contact-play.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await process_frame; await process_frame
	var gate: Dictionary=game.world.access_by_id("workshop-entry")
	game.actors[0].position=Vector2(gate.rect.get_center().x,gate.rect.end.y+180)
	game.schedule.clock_elapsed=(960.0-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.schedule.tick(false); game.workshop.update_gate()
	game.actors[0].position=Vector2(gate.rect.get_center().x+65,gate.rect.end.y+3.01)
	game.actors[0].immune_until=game.elapsed+60
	game.orders.stop(0); game.routines.take_control(0)
	game.map_camera.center_on(game.actors[0].position); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0)
	root.title="监狱风云 · 车间门槛遮挡修复试玩"
	game.show_status("16:00 车间门关闭；可以贴着门外左右走动。",8)
