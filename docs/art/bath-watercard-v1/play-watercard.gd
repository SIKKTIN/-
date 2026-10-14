extends SceneTree
func _initialize() -> void: call_deferred("open")
func open() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://bath-watercard-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://bath-watercard-playtest-buttons.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	root.title="监狱风云 · 水卡充值与洗澡试玩"
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.actors[0].position=game.bath_service.counter_point()
	game.actors[0].moved_this_frame=false
	game.inventory.wallet=20
	game.attributes.values[0].stamina=60
	game.schedule.set_time_speed(0)
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
	game.map_camera.center_on(Vector2(1200,440))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	game._update_ui()
	game.show_status("试玩：已准备20元现金、60体力。按E充值领卡，再走入花洒按E洗澡；移动或E取消退款。",15)
