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
	img.save_png("res://docs/tests/p64-%d-%s.png" % [width,label])
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
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p64/baseline-map.json"))
	var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var physics := current.duplicate(true)
	physics.architecture = baseline.architecture.duplicate(true)
	checks.only_architecture_changed = physics == baseline
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
	game.map_camera.zoom = Vector2(2,2)
	var wall = game.presentation.volumes[8]
	var facade: Dictionary = wall.profile.painted_facade
	checks.two_kitchen_t_junctions = facade.junctions.filter(func(j): return j.asset == "cafeteria_t_20_v31").size() == 2
	checks.outer_l_corner_preserved = facade.junctions[0].asset == "cafeteria_turn_r_v28"
	checks.stems_align_physical_walls = absf(1100+facade.junctions[1].offset[0]+56-game.world.walls[12].position.x) < 0.01 and absf(1100+facade.junctions[2].offset[0]+56-game.world.walls[13].position.x) < 0.01
	var defs: Dictionary = game.presentation.asset_definitions
	var tdef: Dictionary = defs["cafeteria_t_20_v31"]
	var stem_spec: Dictionary = tdef.assembly_patches.filter(func(p): return p.get("role","") == "longitudinal_stem")[0]
	var vdef: Dictionary = defs["cafeteria_wall_v_l_20_v27"]
	var reference_spec: Dictionary = vdef.assembly_patches[0]
	checks.same_source_texture = tdef.texture == vdef.texture
	checks.same_stem_projection = stem_spec.get("transpose",false) == reference_spec.transpose and stem_spec.destination[2] == reference_spec.destination[2]
	checks.contact_bridge_registered = tdef.assembly_patches.any(func(p): return p.get("role","") == "longitudinal_stem" and is_equal_approx(p.destination[1],21) and is_equal_approx(p.destination[3],3))
	checks.same_stone_scale = absf(stem_spec.source[2]/stem_spec.destination[3]-reference_spec.source[2]/reference_spec.destination[3]) < 0.0001
	checks.same_cross_shading_window = stem_spec.source[1] == reference_spec.source[1] and stem_spec.source[3] == reference_spec.source[3]
	checks.original_horizontal_cap_not_replaced = facade.cap_cutouts.size() == 1 and facade.junctions[1].get("reuse_cap",false) and facade.junctions[2].get("reuse_cap",false)
	checks.front_cutout_preserves_top = facade.replace_ranges.all(func(r): return r.size() == 3 and is_equal_approx(r[2],30.48))
	checks.runtime_registered_t_assets = game.world.art_textures.has("cafeteria_t_20_v31") and game.world.art_textures.has("cafeteria_t_v31")
	for side in ["left","right"]:
		var stem: float = 1270 if side == "left" else 1910
		game.map_camera.position = Vector2(stem+10,1300)-Vector2(root.size)/4
		game.map_camera.force_update_scroll()
		var after: Image = await shot("runtime-t-"+side)
		var original: Array = facade.junctions
		var longitudinal = game.presentation.volumes[12 if side == "left" else 13]
		var previous_start: float = longitudinal.profile.render_top_start
		var tile_origin: float = longitudinal.profile.return_wall.tile_origin_y
		checks[side+"_tile_phase_continues_from_stub"] = is_equal_approx(tile_origin,1170.48) and is_equal_approx(previous_start,1226.48)
		# Extrapolate the real straight wall through the stub as a UV reference.
		facade.junctions = original.filter(func(j): return j.asset != "cafeteria_t_20_v31")
		longitudinal.profile.return_wall.tile_origin_y = tile_origin-float(longitudinal.profile.return_wall.tile_size[1])
		longitudinal.profile.render_top_start = tile_origin-3
		wall.queue_redraw()
		longitudinal.queue_redraw()
		var without: Image = await shot("reference-continuous-"+side)
		checks[side+"_original_horizontal_arms_untouched"] = difference(game,after,without,Vector2(stem-35,1158)) < 0.02 and difference(game,after,without,Vector2(stem+55,1158)) < 0.02
		var max_difference := 0.0
		for y in [1168,1169,1176,1183,1190,1197,1204,1211,1218,1222]:
			for x in [2,6,10,14,18]:
				max_difference = maxf(max_difference,difference(game,after,without,Vector2(stem+x,y)))
		checks[side+"_stub_matches_real_straight_wall_pixels"] = max_difference < 0.025
		print("CONTINUITY ",side," max difference ",max_difference)
		checks[side+"_both_notches_clear"] = difference(game,after,without,Vector2(stem-30,1203)) < 0.02 and difference(game,after,without,Vector2(stem+50,1203)) < 0.02
		facade.junctions = original
		longitudinal.profile.return_wall.tile_origin_y = tile_origin
		longitudinal.profile.render_top_start = previous_start
		longitudinal.queue_redraw()
		wall.queue_redraw()
	var expected_junctions: Array = game.world.wall_surfaces[8].painted_facade.junctions.duplicate(true)
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
	checks.editor_and_runtime_same_junctions = c.architecture_preview.nodes["wall:8"].profile.painted_facade.junctions == expected_junctions
	c.origin = c.size/2-Vector2(1920,1300)*c.zoom
	c.queue_redraw()
	await shot("editor-t-right")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p64-%d-t-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
