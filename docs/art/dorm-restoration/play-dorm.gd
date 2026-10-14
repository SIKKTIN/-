extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://dorm-art-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://dorm-art-playtest-buttons.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	root.title="监狱风云 · 寝室装修试玩"
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var room: Dictionary=game.room_config.visibility_rooms.filter(func(r):return r.id=="dorm-0")[0]
	var center:=Vector2(room.rect[0]+280,room.rect[1]+150)
	game.actors[0].position=center+Vector2(90,44)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(center)
	game.map_camera.force_update_scroll()
	game.show_status("寝室装修试玩：靠近蓝灰柜按E翻找，右侧出门可查看屋顶遮挡。",8)
