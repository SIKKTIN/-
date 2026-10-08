extends SceneTree
var game
var checks: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],79)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.fullscreen_ui.set_process(false)
	game.fullscreen_ui.fps_badge.hide()
	game.mini_map.set_process(false)
	var floor=game.get_node("RetainedFloor")
	var old_floor=load("res://qa/p79_reference_floor.gd").new()
	old_floor.game=game
	old_floor.z_index=-2000
	old_floor.texture_filter=game.texture_filter
	game.add_child(old_floor)
	old_floor.hide()
	var layers: Array=[]
	var old_layers: Array=[]
	for layer in game.presentation.scene_layers:
		if layer.kind not in ["ground","ground_static"]:continue
		layers.append(layer)
		var old=load("res://qa/p79_reference_layers.gd").new()
		game.add_child(old)
		old.configure(game,game.presentation,layer.kind)
		old.hide()
		old_layers.append(old)
	var old_map=load("res://qa/p79_reference_minimap.gd").new()
	old_map.game=game
	old_map.clip_contents=true
	old_map.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.get_node("HUD").add_child(old_map)
	old_map.set_process(false)
	old_map.hide()
	for child in game.mini_map.get_children():
		if child is Control:child.hide()
	for period in ["day","night"]:
		game.presentation.lighting.set_period(period)
		for index in range(4):
			var point: Vector2=[Vector2(1340,1016),Vector2(1060,1444),Vector2(750,1300),Vector2(428,414)][index]
			game.actors[0].position=point
			game.map_camera.center_on(point)
			game.room_visibility.tick(0.3)
			game.presentation.tick(0)
			game.fullscreen_ui.refresh()
			game.fullscreen_ui.fps_badge.hide()
			game.mini_map.queue_redraw()
			floor._process(0)
			old_map.position=game.mini_map.position
			old_map.size=game.mini_map.size
			for layer in layers:layer.show()
			floor.show()
			game.mini_map.show()
			old_floor.hide()
			old_map.hide()
			for old in old_layers:old.hide()
			await frame()
			await frame()
			var actual: Image=root.get_texture().get_image()
			floor.hide()
			game.mini_map.hide()
			for layer in layers:layer.hide()
			old_floor.show()
			old_floor.queue_redraw()
			old_map.show()
			old_map.queue_redraw()
			for old in old_layers:old.show();old.queue_redraw()
			await frame()
			var expected: Image=root.get_texture().get_image()
			var key: String=str(period)+str(index)
			checks[key]=actual.get_data()==expected.get_data()
			actual.save_png("res://docs/tests/p79-parity-"+key+"-actual.png")
			expected.save_png("res://docs/tests/p79-parity-"+key+"-reference.png")
			print(key+": "+str(checks[key]))
	for old in old_layers:old.hide()
	old_floor.hide()
	old_map.hide()
	floor.show()
	game.mini_map.show()
	for layer in layers:layer.show()
	game.fullscreen_ui.toggle_menu()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p79-menu-presets.png")
	FileAccess.open("res://docs/tests/p79-visual-parity.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks},"\t"))
	quit()
