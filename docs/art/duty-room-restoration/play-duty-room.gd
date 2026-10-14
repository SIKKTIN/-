extends SceneTree
func _initialize():call_deferred("open")
func open():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://duty-room-playtest.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://duty-room-playtest-buttons.cfg")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	root.title="监狱风云 · 值班室概念还原试玩"
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	var area:Rect2=game.room_visibility.rooms.filter(func(v):return v.id=="duty")[0].area
	game.actors[0].position=Vector2(area.get_center().x-10,area.end.y-65)
	game.actors[0].immune_until=game.elapsed+30
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
	game.map_camera.center_on(area.get_center()+Vector2(0,-30));game.map_camera.force_update_scroll()
	game.show_status("值班室试玩：沿墙查看通讯柜和钥匙柜，靠近柜子按 E 搜索，物品可以拖入背包和放回。",8)
