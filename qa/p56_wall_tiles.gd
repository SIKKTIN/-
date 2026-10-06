extends SceneTree

var game
var native := false
var width := 1200
var checks := {}

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func shot(label: String) -> Image:
	if not native: return null
	await frame()
	await frame()
	var image := root.get_texture().get_image()
	image.save_png("res://docs/tests/p56-%d-%s.png" % [width,label])
	return image

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): width = int(args[0])
	root.content_scale_size = Vector2i(width,720 if width == 1200 else 540)
	root.size = root.content_scale_size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],55)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.schedule.clock_elapsed = (780.0-480)/1440*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.actors[0].position = Vector2(1010,1120)
	game.actors[1].position = Vector2(400,1430)
	game.guard.position = Vector2(700,1600)
	game.dog.position = Vector2(710,1530)
	game.map_camera.center_on(Vector2(1000,1180))
	game.presentation.tick(0)
	var ui = game.fullscreen_ui
	await create_timer(2.2,true,false,true).timeout
	await frame()
	checks.fps_numeric = ui.fps_label.text.begins_with("FPS ") and ui.fps_label.text.substr(4).is_valid_int() and int(ui.fps_label.text.substr(4)) > 0
	checks.fps_visible = ui.fps_badge.is_visible_in_tree()
	checks.fps_ignores_input = ui.fps_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and ui.fps_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
	checks.fps_inside_safe_area = ui.safe_area().encloses(ui.fps_badge.get_global_rect())
	checks.fps_outside_minimap = not ui.fps_badge.get_global_rect().intersects(game.mini_map.get_global_rect())
	checks.fps_outside_goal = not ui.fps_badge.get_global_rect().intersects(ui.goal.get_global_rect())
	checks.no_column_repetition = [9,10,12,13].all(func(i): return game.world.wall_surfaces[i].has("return_wall") and not game.world.wall_surfaces[i].has("return_material"))
	checks.top_asset_loaded = game.world.art_textures.has("cafeteria_wall_v_v26")
	checks.end_asset_loaded = game.world.art_textures.has("cafeteria_end_v26")
	checks.corner_asset_loaded = game.world.art_textures.has("cafeteria_corner_l_v26")
	var tile_ids: Array = game.presentation.asset_definitions.keys().filter(func(id): return str(id).ends_with("_v26"))
	checks.fourteen_tiles_loaded = tile_ids.size() == 14 and tile_ids.all(func(id): return game.world.art_textures.has(id))
	checks.single_master_texture = tile_ids.all(func(id): return game.presentation.asset_definitions[id].texture == "res://art/architecture/v26/wall_tiles_master_v26.png")
	checks.shared_gpu_texture = tile_ids.all(func(id): return game.world.art_textures[id] == game.world.art_textures["cafeteria_wall_h_v26"])
	checks.same_stone_period = tile_ids.all(func(id): return game.presentation.asset_definitions[id].tile_period == 128)
	checks.all_horizontal_walls_tiled = [7,8,11].all(func(i): return game.world.wall_surfaces[i].painted_facade.layout == "tiled")
	checks.four_junctions_registered = game.world.wall_surfaces[7].painted_facade.junctions.size() == 1 and game.world.wall_surfaces[8].painted_facade.junctions.size() == 3
	checks.return_continues_below_corner = [9,10,12,13].all(func(i): return absf(game.world.wall_surfaces[i].render_top_start-1297.5) < 0.001)
	checks.roof_unchanged = game.presentation.roof_buildings.size() == 3 and game.presentation.roof_buildings.all(func(b): return b.roof_overlay != null)
	var walls: Array = game.presentation.volumes.filter(func(v): return v.kind == "wall" and v.wall_index in [7,8])
	checks.safe_shader_on_wall = walls.all(func(v): return v.material.shader.resource_path.ends_with("safe_edges_v25.gdshader"))
	var lintel
	for v in game.presentation.volumes:
		if v.kind == "fixture" and v.lintel_visual != null: lintel = v.lintel_visual
	checks.lintel_assembled = lintel != null and lintel.texture == null
	await shot("walls-hud")
	game.get_node("HUD").visible = false
	await shot("walls-unobscured")
	game.get_node("HUD").visible = true
	var previous_sample: int = ui.fps_sample_time
	game.routine_panel.toggle()
	checks.planner_pauses = paused
	await create_timer(0.65,true,false,true).timeout
	checks.fps_updates_while_paused = ui.fps_sample_time > previous_sample and int(ui.fps_label.text.substr(4)) > 0
	checks.fps_below_planner = ui.fps_badge.z_index < game.routine_panel.panel.z_index
	await shot("planner-fps-layer")
	game.routine_panel.close()
	checks.resume = not paused
	var doc = load("res://scripts/editor/map_document.gd").new()
	doc.open_file("res://data/rooms/r04.json")
	checks.map_valid = doc.validate().errors.is_empty()
	var failures: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"native":native,"width":width,"checks":checks,"passed":checks.size()-failures.size(),"total":checks.size(),"failed":failures,"fps":ui.fps_label.text}
	FileAccess.open("res://docs/tests/p56-wall-fps-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
