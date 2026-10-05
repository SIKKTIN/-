extends SceneTree

var game
var checks := {}

func _initialize() -> void:
	root.gui_embed_subwindows = true
	call_deferred("run")

func frame() -> void:
	root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw

func shot(label_text: String) -> void:
	game.presentation.tick(0)
	game._update_ui()
	game.mini_map.queue_redraw()
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p40b-"+label_text+".png")

func marker_pixel(position: Vector2, color: Color) -> bool:
	var point: Vector2 = game.mini_map.get_global_transform()*game.mini_map.to_map(position)
	point = root.get_final_transform()*point
	var pixel := root.get_texture().get_image().get_pixelv(Vector2i(point.round()))
	return absf(pixel.r-color.r)+absf(pixel.g-color.g)+absf(pixel.b-color.b) < 0.12

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],40)
	game.routine_panel.close()
	game.schedule.set_time_speed(1)
	var id: String = game.trade.actors.keys()[0]
	var npc = game.trade.actors[id]
	var start: Vector2 = npc.position
	for index in range(90):
		game._process(1.0/30)
	checks.real_merchant_displaced = npc.position.distance_to(start) > 100
	checks.runtime_position_synced = Vector2(game.trade.merchants[id].position[0],game.trade.merchants[id].position[1]) == npc.position
	game.map_camera.center_on(npc.position)
	await shot("moving-marker")
	checks.moving_marker_rendered = marker_pixel(npc.position,Color("a79768"))
	checks.old_fixed_marker_not_rendered = not marker_pixel(start,Color("a79768"))
	for index in range(4000):
		game._process(1.0/30)
		if game.schedule.clock_minutes() >= 720:
			break
	checks.noon_trader_open = game.trade.is_open(id)
	game.map_camera.center_on(npc.position)
	await shot("open-marker")
	checks.open_marker_rendered = marker_pixel(npc.position,Color("ebcb75"))
	game.schedule.set_time_speed(0)
	game.orders.clear()
	game.routines.take_control(0)
	game.actors[0].position = Vector2(900,1130)
	game.guard.position = Vector2(820,1130)
	game.guard.facing = Vector2.RIGHT
	game.actors[0].immune_until = 0
	checks.day_chat_available = game.skills.target_reason(game.actors[0]) == ""
	checks.chat_starts = game.skills.toggle(0)
	checks.chat_copy_no_catch = "非戒备" in game.status_text and "不追捕" in game.status_text
	game.guard.tick(0)
	checks.chat_preserved_day = game.guard.state == "talking" and game.captures == 0
	game.map_camera.locate_selected()
	await shot("day-chat")
	game.schedule.clock_elapsed = (1200.0-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	game.trade.tick(0)
	checks.night_chat_disallowed = "警戒" in game.skills.target_reason(game.actors[0])
	await shot("closed-marker")
	checks.night_closed_marker_visible = marker_pixel(npc.position,Color("a79768"))
	var passed: bool = checks.values().all(func(v): return v)
	FileAccess.open("res://docs/tests/p40b-map-chat.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Native D3D12 actual full merchant morning commute and framebuffer pixel checks at moving/open/night markers. Isolated actor/guard positions for chat."},"\t")+"\n")
	print("P40B passed=",passed," failures=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
