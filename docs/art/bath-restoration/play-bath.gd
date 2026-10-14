extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-art-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://bath-art-playtest-buttons.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	root.title="监狱风云 · 公共浴室概念还原试玩"
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="bath")[0]
	var door=game.room_visibility.doorways.by_id("fixture:campus-bath")
	game.actors[0].position=Vector2(door.visual_rect.get_center().x,room.area.position.y+370)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(Vector2(room.area.get_center().x,room.area.position.y+220))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	game.show_status("公共浴室试玩：走入六个淋浴位；靠近更衣柜按 E 搜刮；出门查看新屋顶。",8)
