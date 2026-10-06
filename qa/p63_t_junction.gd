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
	img.save_png("res://docs/tests/p63-%d-%s.png" % [width,label])
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
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/p63/baseline-map.json"))
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
	checks.two_kitchen_t_junctions = facade.junctions.filter(func(j): return j.asset == "cafeteria_t_20_v30").size() == 2
	checks.outer_l_corner_preserved = facade.junctions[0].asset == "cafeteria_turn_r_v28"
	checks.stems_align_physical_walls = absf(1100+facade.junctions[1].offset[0]+56-game.world.walls[12].position.x) < 0.01 and absf(1100+facade.junctions[2].offset[0]+56-game.world.walls[13].position.x) < 0.01
	checks.runtime_registered_t_assets = game.world.art_textures.has("cafeteria_t_20_v30") and game.world.art_textures.has("cafeteria_t_v30")
	for side in ["left","right"]:
		var stem: float = 1270 if side == "left" else 1910
		game.map_camera.position = Vector2(stem+10,1190)-Vector2(root.size)/4
		game.map_camera.force_update_scroll()
		var after: Image = await shot("runtime-t-"+side)
		var original: Array = facade.junctions
		facade.junctions = original.filter(func(j): return j.asset != "cafeteria_t_20_v30")
		wall.queue_redraw()
		await frame()
		await frame()
		var without := root.get_texture().get_image()
		checks[side+"_both_horizontal_arms_drawn"] = difference(game,after,without,Vector2(stem-35,1158)) > 0.04 and difference(game,after,without,Vector2(stem+55,1158)) > 0.04
		checks[side+"_center_stem_drawn"] = difference(game,after,without,Vector2(stem+10,1203)) > 0.04
		checks[side+"_both_notches_clear"] = difference(game,after,without,Vector2(stem-30,1203)) < 0.02 and difference(game,after,without,Vector2(stem+50,1203)) < 0.02
		facade.junctions = original
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
	c.zoom = 1.4
	c.origin = c.size/2-Vector2(1280,1200)*c.zoom
	c.queue_redraw()
	await shot("editor-t-left")
	checks.editor_and_runtime_same_junctions = c.architecture_preview.nodes["wall:8"].profile.painted_facade.junctions == expected_junctions
	c.origin = c.size/2-Vector2(1920,1200)*c.zoom
	c.queue_redraw()
	await shot("editor-t-right")
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p63-%d-t-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
