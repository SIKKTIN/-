extends SceneTree

var kept_icons: Array[Texture2D] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	var original := FileAccess.get_sha256("res://data/rooms/r04.json")
	var catalogue = load("res://scripts/editor/editor_catalog.gd").new()
	var ids: Array = catalogue.assets.keys().filter(func(id): return str(id).ends_with("_v27"))
	var panel := Control.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(ids.size()):
		var entry: Dictionary = catalogue.entries.filter(func(e): return e.id == ids[i])[0]
		var icon: Texture2D = catalogue.icon(entry)
		kept_icons.append(icon)
		var view := TextureRect.new()
		view.position = Vector2(22+i*82,20)
		view.size = Vector2(76,110)
		view.texture = icon
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(view)
	var doc = load("res://scripts/editor/map_document.gd").new()
	doc.data = {"id":"p57_fixture_probe","bounds":[0,0,600,220],"starts":[],"walls":[],"fixtures":[
		{"asset_id":"cafeteria_wing_left_v24","rect":[40,40,128,114]},
		{"asset_id":"cafeteria_wall_v_l_v27","rect":[240,20,24,128]},
		{"asset_id":"cafeteria_corner_l_v27","rect":[360,20,80,150]}
	]}
	var canvas = load("res://scripts/editor/map_canvas.gd").new()
	canvas.position = Vector2(20,160)
	canvas.size = Vector2(1160,530)
	panel.add_child(canvas)
	canvas.setup(doc)
	canvas.fit()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://docs/tests/p57-editor-components-final.png")
	var cutout: Vector2 = canvas.position+canvas.screen(Vector2(430,151))
	var background: Vector2 = canvas.position+canvas.screen(Vector2(510,151))
	var top: Vector2 = canvas.position+canvas.screen(Vector2(100,50))
	var base: Vector2 = canvas.position+canvas.screen(Vector2(100,140))
	var checks := {
		"ten_mesh_icons":kept_icons.size() == 10 and kept_icons.all(func(t): return t is MeshTexture and t.mesh != null),
		"editor_L_keeps_empty_corner":image.get_pixelv(Vector2i(cutout)).is_equal_approx(image.get_pixelv(Vector2i(background))),
		"editor_H_keeps_top_and_base":image.get_pixelv(Vector2i(top)).get_luminance() > image.get_pixelv(Vector2i(base)).get_luminance()*1.2,
		"source_map_unchanged":FileAccess.get_sha256("res://data/rooms/r04.json") == original
	}
	panel.hide()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],56)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.get_node("HUD").hide()
	game.presentation.tick(0)
	game.map_camera.following = false
	game.map_camera.zoom = Vector2(1.5,1.5)
	game.map_camera.position = Vector2(680,620)
	game.map_camera.force_update_scroll()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	for fixture in [
		{"asset_id":"cafeteria_wing_left_v24","rect":Rect2(760,780,128,114),"render_size":[128,114]},
		{"asset_id":"cafeteria_wall_v_l_v27","rect":Rect2(1040,760,24,128),"render_size":[24,128]},
		{"asset_id":"cafeteria_corner_l_v27","rect":Rect2(1280,760,80,150),"render_size":[80,150]}
	]:
		fixture.blocks_movement = false
		fixture.blocks_sight = false
		game.world.fixtures.append(fixture)
	game.presentation._refresh_volumes()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	after.save_png("res://docs/tests/p57-runtime-components-final.png")
	var empty: Vector2 = game.get_global_transform_with_canvas()*Vector2(1350,900)
	print("CUTOUT_COLORS ",before.get_pixelv(Vector2i(empty))," ",after.get_pixelv(Vector2i(empty)))
	checks.runtime_L_keeps_floor_cutout = before.get_pixelv(Vector2i(empty)).is_equal_approx(after.get_pixelv(Vector2i(empty)))
	checks.preview_never_saved_map = FileAccess.get_sha256("res://data/rooms/r04.json") == original
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var result := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p57-editor-components-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit(0 if failed.is_empty() else 1)
