extends SceneTree
var game
func _initialize() -> void: call_deferred("open")
func open() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://clinic-art-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://clinic-art-playtest-buttons.cfg")
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	root.title = "监狱风云 · 医务室侧滑门昼夜试玩"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var door = game.room_visibility.doorways.by_id("fixture:campus-clinic")
	game.actors[0].position = Vector2(door.visual_rect.get_center().x,door.visual_rect.end.y+110)
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
	var cover = game.room_visibility.covers.filter(func(c):return c.room.id=="clinic")[0]
	game.map_camera.center_on(cover.roof.get_center()+Vector2(0,100))
	game.map_camera.force_update_scroll()
	var layer := CanvasLayer.new()
	layer.layer = 99
	game.add_child(layer)
	var controls := HBoxContainer.new()
	controls.position = Vector2(420,765)
	controls.theme = game.cards[0].theme
	layer.add_child(controls)
	for entry in [["白天 08:00",480],["夜间 20:00",1200]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(200,44)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_time.bind(float(entry[1])))
		controls.add_child(button)
	game.show_status("侧滑门试玩：白天可进入；夜间离场后关门。下方按钮切换昼夜。",8)

func set_time(minutes: float) -> void:
	game.schedule.clock_elapsed=(minutes-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.schedule.tick(false)
	game.show_status("医务室开放时间 08:00–20:00；门口有人时暂缓关闭。",4)
