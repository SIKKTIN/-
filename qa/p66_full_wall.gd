extends SceneTree
var checks := {}
var width := 1200
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(label: String) -> Image:
	await frame()
	await frame()
	var img := root.get_texture().get_image()
	img.save_png("res://docs/tests/p66-%d-%s.png" % [width,label])
	return img
func difference(game, a: Image, b: Image, point: Vector2) -> float:
	var p := Vector2i(game.get_global_transform_with_canvas()*point)
	var ca := a.get_pixelv(p)
	var cb := b.get_pixelv(p)
	return Vector3(ca.r,ca.g,ca.b).distance_to(Vector3(cb.r,cb.g,cb.b))
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): width = int(args[0])
	root.size = Vector2i(width,720 if width == 1200 else 640)
	root.content_scale_size = root.size
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p66/baseline-map.json"))
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var physics := current.duplicate(true)
	physics.architecture = baseline.architecture.duplicate(true)
	for i in range(physics.fixtures.size()):
		if physics.fixtures[i].id == "cafeteria-door-visual": physics.fixtures[i].lintel_asset = baseline.fixtures[i].lintel_asset
	checks.only_architecture_and_lintel_changed = physics == baseline
	checks.independent_sign_unchanged = current.cafeteria.wall_sign == baseline.cafeteria.wall_sign
	var validation = load("res://scripts/editor/map_document.gd").new()
	validation.data = current
	checks.new_map_valid = validation.validate().errors.is_empty()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],62)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.get_node("HUD").hide()
	game.presentation.tick(0)
	game.map_camera.following = false
	var defs: Dictionary = game.presentation.asset_definitions
	var wall = game.presentation.volumes[8]
	var facade: Dictionary = wall.profile.painted_facade
	var tj: Array = facade.junctions.filter(func(j): return j.asset == "cafeteria_t_20_v33")
	checks.two_complete_short_t = tj.size() == 2 and tj.all(func(j): return Vector2(j["size"][0],j["size"][1]) == Vector2(68,121.5) and not j.get("reuse_cap",false))
	checks.roots_align_existing_physics = is_equal_approx(1100+tj[0].offset[0]+24,1270) and is_equal_approx(1100+tj[1].offset[0]+24,1910)
	checks.full_body_cutout = facade.replace_ranges.any(func(r): return r.size() == 2 and is_equal_approx(r[0],146) and is_equal_approx(r[1],68)) and facade.replace_ranges.any(func(r): return r.size() == 2 and is_equal_approx(r[0],786) and is_equal_approx(r[1],68))
	checks.no_cap_only_cutouts = not facade.has("cap_cutouts")
	var tdef: Dictionary = defs["cafeteria_t_20_v33"]
	var stem: Dictionary = tdef.assembly_patches.filter(func(p): return p.destination[0] == 24 and p.destination[2] == 20)[0]
	var vdef: Dictionary = defs["cafeteria_wall_v_l_20_v33"]
	var repeat: Dictionary = vdef.assembly_patches[0]
	checks.same_source_texture = tdef.texture == vdef.texture
	checks.same_cross_uv = stem.source[0] == repeat.source[0] and stem.source[2] == repeat.source[2]
	checks.same_run_scale = absf(stem.source[3]/stem.destination[3]-repeat.source[3]/repeat.destination[3]) < 0.0001
	checks.full_h_facades_new_source = [7,8,11].all(func(i): return str(game.presentation.volumes[i].profile.painted_facade.asset).ends_with("_v33") and game.presentation.volumes[i].display_rect.size.y == 121.5)
	checks.all_vertical_ends_same_source = [9,10,12,13].all(func(i): return defs[game.presentation.volumes[i].profile.return_wall.top].texture == tdef.texture and defs[game.presentation.volumes[i].profile.return_wall.end].texture == tdef.texture)
	game.map_camera.zoom = Vector2(2,2)
	for side in ["left","right"]:
		var x: float = 1270 if side == "left" else 1910
		game.map_camera.position = Vector2(x+10,1300)-Vector2(root.size)/4
		game.map_camera.force_update_scroll()
		game.queue_redraw()
		var after: Image = await shot("runtime-t-"+side)
		var original: Array = facade.junctions
		facade.junctions = original.filter(func(j): return j.asset != "cafeteria_t_20_v33")
		wall.queue_redraw()
		var without: Image = await shot("without-t-"+side)
		checks[side+"_entire_body_replaced"] = difference(game,after,without,Vector2(x-16,1178)) > 0.04
		checks[side+"_entire_foot_replaced"] = difference(game,after,without,Vector2(x-16,1250)) > 0.04
		checks[side+"_root_at_wall_top"] = difference(game,after,without,Vector2(x+8,1148)) > 0.04
		var node = game.presentation.volumes[12 if side == "left" else 13]
		var previous_start: float = node.profile.render_top_start
		var origin: float = node.profile.return_wall.tile_origin_y
		checks[side+"_long_wall_from_full_body_bottom"] = is_equal_approx(previous_start,1261.5) and is_equal_approx(origin,1222.7513513513513)
		node.profile.return_wall.tile_origin_y = origin-float(node.profile.return_wall.tile_size[1])
		node.profile.render_top_start = origin
		node.queue_redraw()
		var reference: Image = await shot("reference-continuous-"+side)
		var maximum := 0.0
		for y in [1230,1236,1242,1248,1254,1260]:
			for dx in [2,6,10,14,18]: maximum = maxf(maximum,difference(game,after,reference,Vector2(x+dx,y)))
		checks[side+"_actual_uv_continuity"] = maximum < 0.025
		print("CONTINUITY ",side," max difference ",maximum)
		facade.junctions = original
		node.profile.return_wall.tile_origin_y = origin
		node.profile.render_top_start = previous_start
		node.queue_redraw()
		wall.queue_redraw()
	game.map_camera.zoom = Vector2(0.75,0.75)
	game.map_camera.position = Vector2(1372,1550)-Vector2(root.size)/(2*0.75)
	game.map_camera.force_update_scroll()
	game.queue_redraw()
	await shot("runtime-overview-closed")
	var gate: Dictionary = game.world.access_by_id("cafeteria-entry")
	gate.closed = false
	game.presentation.tick(0)
	await shot("runtime-overview-open")
	var door_node = game.presentation.volumes[game.world.walls.size()+46]
	checks.independent_gate_switches = door_node.prop_id() == "cafeteria_gate_open_v23" and game.world.fixtures[46].lintel_asset == "cafeteria_lintel_v33"
	var expected: Array = game.world.wall_surfaces[8].painted_facade.junctions.duplicate(true)
	game.queue_free()
	await frame()
	await frame()
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	var c = editor.canvas
	c.zoom = 1.2
	c.origin = c.size/2-Vector2(1280,1300)*c.zoom
	c.queue_redraw()
	await shot("editor-t-left")
	checks.editor_runtime_same_full_wall = c.architecture_preview.nodes["wall:8"].profile.painted_facade.junctions == expected
	c.origin = c.size/2-Vector2(1920,1300)*c.zoom
	c.queue_redraw()
	await shot("editor-t-right")
	c.zoom = 0.42
	c.origin = c.size/2-Vector2(1372,1570)*c.zoom
	c.queue_redraw()
	await shot("editor-overview")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p66-%d-full-wall-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
