extends SceneTree
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-clearance-v2-preview.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"; root.add_child(game); current_scene=game
	await process_frame
	game.orders.clear()
	var door=game.room_visibility.doorways.by_id("dorm-0")
	door.gate.closed=false; game.world._changed(true)
	game.actors[0].position=Vector2(door.visual_rect.position.x-95,door.gate.rect.position.y+20)
	game.actors[0].immune_until=game.elapsed+600
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0); game.room_visibility.doorways.tick(true)
	root.title="监狱风云 · 宿舍门碰撞与屋顶遮挡修正"
	print("DORM_CLEARANCE_PREVIEW_READY")
