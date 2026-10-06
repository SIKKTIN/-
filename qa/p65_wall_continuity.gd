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
	img.save_png("res://docs/tests/p65-%d-%s.png" % [width,label])
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
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p65/baseline-map.json"))
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
	checks.two_kitchen_t_junctions = facade.junctions.filter(func(j): return j.asset == "cafeteria_t_20_v32").size() == 2
	checks.outer_l_corner_preserved = facade.junctions[0].asset == "cafeteria_turn_r_v28"
	checks.stems_align_physical_walls = absf(1100+facade.junctions[1].offset[0]+56-game.world.walls[12].position.x) < 0.01 and absf(1100+facade.junctions[2].offset[0]+56-game.world.walls[13].position.x) < 0.01
	var defs: Dictionary = game.presentation.asset_definitions
	var tdef: Dictionary = defs["cafeteria_t_20_v32"]
	var vdef: Dictionary = defs["cafeteria_wall_v_l_20_v32"]
	checks.same_source_texture = tdef.texture == vdef.texture
	var stem_spec: Dictionary = tdef.assembly_patches.filter(func(q): return q.get("role","") == "longitudinal_stem")[0]
	var repeat_spec: Dictionary = vdef.assembly_patches[0]
	checks.same_uv_cross_window = stem_spec.source[0] == repeat_spec.source[0] and stem_spec.source[2] == repeat_spec.source[2]
	checks.same_uv_run_scale = absf(stem_spec.source[3]/stem_spec.destination[3]-repeat_spec.source[3]/repeat_spec.destination[3]) < 0.0001

	checks.full_rounded_cap_used = not facade.junctions[1].get("reuse_cap",false) and not facade.junctions[2].get("reuse_cap",false)
	checks.old_low_join_retired = facade.junctions.all(func(j): return not str(j.asset).ends_with("_v31"))
	checks.local_cap_replacement = facade.cap_cutouts.size() == 3
	checks.runtime_registered_t_assets = game.world.art_textures.has("cafeteria_t_20_v32") and game.world.art_textures.has("cafeteria_t_v32")
	for side in ["left","right"]:
		var stem: float = 1270 if side == "left" else 1910
		game.map_camera.position = Vector2(stem+10,1300)-Vector2(root.size)/4
		game.map_camera.force_update_scroll()
		var after: Image = await shot("runtime-t-"+side)
		var original: Array = facade.junctions
		var longitudinal = game.presentation.volumes[12 if side == "left" else 13]
		var previous_start: float = longitudinal.profile.render_top_start
		var tile_origin: float = longitudinal.profile.return_wall.tile_origin_y
		checks[side+"_new_long_wall_used"] = str(longitudinal.profile.return_wall.top).ends_with("_v32")
		checks[side+"_stub_clip_unchanged"] = is_equal_approx(previous_start,1226.48)
		# Remove the new component to confirm actual drawing coverage, not only registry.
		facade.junctions = original.filter(func(j): return j.asset != "cafeteria_t_20_v32")
		wall.queue_redraw()
		var without: Image = await shot("without-t-"+side)
		checks[side+"_north_root_visible_same_height"] = difference(game,after,without,Vector2(stem+8,1158)) > 0.04
		checks[side+"_both_horizontal_arms_drawn"] = difference(game,after,without,Vector2(stem-35,1158)) > 0.04 and difference(game,after,without,Vector2(stem+55,1158)) > 0.04
		checks[side+"_longitudinal_stub_drawn"] = difference(game,after,without,Vector2(stem+8,1203)) > 0.04
		checks[side+"_outer_notches_clear"] = difference(game,after,without,Vector2(stem-30,1203)) < 0.02 and difference(game,after,without,Vector2(stem+50,1203)) < 0.02
		# Compare the actual stub with the real V drawn upward at the same phase.
		longitudinal.profile.return_wall.tile_origin_y = tile_origin-float(longitudinal.profile.return_wall.tile_size[1])
		longitudinal.profile.render_top_start = tile_origin
		longitudinal.queue_redraw()
		var reference: Image = await shot("reference-continuous-"+side)
		var maximum := 0.0
		for y in [1177,1184,1191,1198,1205,1212,1219,1223]:
			for x in [2,6,10,14,18]: maximum = maxf(maximum,difference(game,after,reference,Vector2(stem+x,y)))
		checks[side+"_actual_same_uv_reference"] = maximum < 0.025
		print("CONTINUITY ",side," max difference ",maximum)

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
	FileAccess.open("res://docs/tests/p65-%d-t-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
