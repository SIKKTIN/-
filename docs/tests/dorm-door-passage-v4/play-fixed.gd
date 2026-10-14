extends SceneTree
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-passage-v4-preview.cfg")
	root.size=Vector2i(1200,720); root.content_scale_size=root.size
	var game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"; root.add_child(game); current_scene=game
	await process_frame
	game.orders.clear()
	var door=game.room_visibility.doorways.by_id("dorm-0")
	door.gate.closed=false; game.world._changed(true)
	var upper: Rect2=door.transform*door.patch_parts[0].area
	var lower: Rect2=door.transform*door.patch_parts[1].area
	var y := (upper.end.y+lower.position.y)/2-preload("res://scripts/core/actor_footprint.gd").DOOR_BODY.get_center().y
	game.actors[0].position=Vector2(door.visual_rect.position.x-12,y)
	game.actors[0].immune_until=game.elapsed+600
	game.map_camera.center_on(door.visual_rect.get_center()+Vector2(-90,-5)); game.map_camera.force_update_scroll()
	game.room_visibility.tick(0,true); game.presentation.tick(0); game.room_visibility.doorways.tick(true)
	root.title="监狱风云 · 宿舍门真实开口通行 V4"
	print("DORM_PASSAGE_V4_READY position=",game.actors[0].position," middle-clear=",game.world.motion_clear(game.actors[0].position,Vector2(door.visual_rect.end.x+75,y),game.actors[0],false,true)," upper-blocked=",not game.world.motion_clear(Vector2(650,door.visual_rect.position.y+65),Vector2(760,door.visual_rect.position.y+65),game.actors[0],false,true))
