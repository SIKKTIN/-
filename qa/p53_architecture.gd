extends SceneTree

var game
var checks := {}
var native := false
var width := 1200

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	game.presentation.tick(0)

func fresh() -> void:
	game.load_room("r04",["chat","lockpick","backpack"],53)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.orders.clear()

func door_volume(id: String):
	for volume in game.presentation.volumes:
		if volume.kind == "fixture" and str(game.world.fixtures[volume.wall_index].get("access_id","")) == id: return volume
	return null

func shot(label: String, center: Vector2) -> Image:
	if not native: return null
	game.map_camera.center_on(center)
	game.map_camera.following = false
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	var image := root.get_texture().get_image()
	image.save_png("res://docs/tests/p53-%d-%s.png" % [width,label])
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
	fresh()
	checks.roof_count = game.presentation.roof_buildings.size() == 3
	checks.all_assets = ["solitary_roof_v23","solitary_wall_front_v23","solitary_coping_v23","cafeteria_wall_front_v23","cafeteria_coping_v23","solitary_door_closed_v23","solitary_door_open_v23","cafeteria_gate_closed_v23","cafeteria_gate_open_v23"].all(func(id): return game.world.art_textures.has(id))
	checks.inside_occluded = game.world.roofed_cells.all(func(spec): return game.world.is_under_roof(spec.rect.get_center()))
	checks.outside_unoccluded = game.room_access.cells().all(func(cell): return not game.world.is_under_roof(Vector2(cell.release[0],cell.release[1])))
	checks.canteen_equal_height = game.world.wall_surfaces[7].height == game.world.wall_surfaces[8].height
	var wings: Array = game.presentation.volumes.filter(func(v): return v.kind == "wall" and v.wall_index in [7,8])
	checks.wings_equal_baseline = wings[0].footprint.end.y == wings[1].footprint.end.y
	checks.wings_equal_coping = wings[0].elevation == wings[1].elevation and wings[0].asset_id("wall_front","") == wings[1].asset_id("wall_front","")
	checks.roof_wall_suppression = game.presentation.volumes.filter(func(v): return v.kind == "wall" and v.wall_index >= 23).all(func(v): return not v.visible)
	var gate = door_volume("cafeteria-entry")
	checks.gate_height = gate.display_rect.size.y == 110
	checks.gate_baseline = gate.display_rect.end.y == wings[0].footprint.end.y
	minute(719.99)
	checks.closed_before_noon = game.world.access_by_id("cafeteria-entry").closed and gate.prop_id() == "cafeteria_gate_closed_v23"
	checks.closed_blocks = not game.world.motion_clear(Vector2(1010,1100),Vector2(1010,1300),game.actors[0])
	game.actors[0].position = Vector2(1010,1090)
	game.actors[1].position = Vector2(590,1320)
	game.actors[2].position = Vector2(680,1540)
	game.guard.position = Vector2(690,1560)
	game.dog.position = Vector2(750,1530)
	game.presentation.tick(0)
	await shot("entrance-closed",Vector2(1030,1300))
	var closed_rect: Rect2 = gate.display_rect
	minute(720)
	checks.noon_open = not game.world.access_by_id("cafeteria-entry").closed and gate.prop_id() == "cafeteria_gate_open_v23"
	checks.state_same_anchor = gate.display_rect == closed_rect
	checks.open_motion = game.world.motion_clear(Vector2(1010,1100),Vector2(1010,1300),game.actors[0])
	checks.open_path = not game.world.find_path(Vector2(1010,1100),Vector2(1010,1300),game.actors[0],false).is_empty()
	await shot("entrance-open",Vector2(1030,1300))
	minute(840)
	checks.two_closed = game.world.access_by_id("cafeteria-entry").closed and gate.prop_id() == "cafeteria_gate_closed_v23"
	minute(790)
	game.capture_actor(0)
	game.actors[1].position = Vector2(400,1430)
	game.actors[2].position = Vector2(590,1290)
	game.presentation.tick(0)
	checks.body_hidden = not game.presentation.visuals[0].visible
	checks.exterior_body_visible = game.presentation.visuals[1].visible and game.presentation.visuals[2].visible
	checks.external_custody_label = "伙伴1" in game.presentation.roof_buildings[0].status_label.text and "禁闭" in game.presentation.roof_buildings[0].status_label.text
	checks.solitary_locked = door_volume("solitary-0").prop_id() == "solitary_door_closed_v23"
	checks.solitary_sight_closed = not game.world.line_clear(Vector2(400,1320),Vector2(400,1430))
	var before := await shot("solitary-closed",Vector2(625,1350))
	game.actors[0].position = Vector2(440,1280)
	game.inventory.add_ground("scrap",Vector2(285,1200))
	game.items_view.queue_redraw()
	game.presentation.tick(0)
	var after := await shot("roof-occlusion",Vector2(625,1350))
	if native:
		# Same camera, lights, custody label and UI; moving an interior actor must
		# produce zero changed pixels in the opaque top of the first building.
		var world_area := Rect2(180,1150,300,100)
		var a: Vector2 = game.get_global_transform_with_canvas()*world_area.position
		var b: Vector2 = game.get_global_transform_with_canvas()*world_area.end
		var crop := Rect2i(Vector2i(a),Vector2i(b-a)).intersection(Rect2i(Vector2i.ZERO,root.size))
		checks.roof_no_actor_pixel_leak = before.get_region(crop).get_data() == after.get_region(crop).get_data()
	checks.rescue_toggle = game.skills.toggle(1)
	game.skills.tick(5)
	game.presentation.tick(0)
	checks.rescue_kept = not game.actors[0].confined and door_volume("solitary-0").prop_id() == "solitary_door_open_v23"
	checks.body_returns = game.presentation.visuals[0].visible
	checks.solitary_sight_open = game.world.line_clear(Vector2(400,1320),Vector2(400,1430))
	await shot("solitary-open",Vector2(625,1350))
	game.capture_actor(2)
	game.presentation.tick(0)
	checks.third_body_hidden = not game.presentation.visuals[2].visible
	minute(790+120)
	game.presentation.tick(0)
	checks.two_hour_release_kept = not game.actors[2].confined and game.presentation.visuals[2].visible
	minute(1440)
	await shot("architecture-night",Vector2(625,1350))
	var doc = load("res://scripts/editor/map_document.gd").new()
	doc.open_file("res://data/rooms/r04.json")
	checks.editor_valid = doc.validate().errors.is_empty()
	var original = doc.data.duplicate(true)
	doc.remove({"group":"walls","index":0})
	checks.reindex_on_delete = doc.wall_surface(6).get("height",0) == 110 and doc.wall_surface(7).get("height",0) == 110
	doc.undo()
	checks.delete_undo = doc.data == original
	var ref: Dictionary = doc.duplicate_entry({"group":"walls","index":7})
	checks.style_on_duplicate = doc.wall_surface(ref.index).get("front","") == "cafeteria_wall_front_v23"
	doc.undo()
	var raw = JSON.parse_string(doc.text())
	checks.roundtrip_roof = raw.confinement.cells.all(func(cell): return cell.building.roofed)
	checks.roundtrip_walls = raw.architecture.wall_surfaces.size() == 7
	doc.set_property({"group":"confinement","index":0},"building",{"roofed":false,"height":110})
	checks.toggle_roof = not doc.data.confinement.cells[0].building.roofed
	doc.undo()
	checks.roof_undo = doc.data == original
	var malformed = original.duplicate(true)
	malformed.architecture.wall_surfaces[0].wall_index = 999
	checks.reject_bad_wall_reference = doc.check_shape(malformed) != ""
	for room in ["r01","r02","r03"]:
		game.load_room(room,["chat","lockpick","backpack"],53)
		game.routine_panel.close()
		game.presentation.tick(0)
		checks[room+"_compatible"] = game.world.roofed_cells.is_empty() and game.presentation.roof_buildings.is_empty() and game.world.wall_surfaces.is_empty() and game.presentation.visuals.all(func(v): return v.visible)
	fresh()
	checks.same_room_reload_roof = game.presentation.roof_buildings.size() == 3
	var bad: Array = checks.keys().filter(func(key): return not checks[key])
	var report := {"native":native,"width":width,"passed":checks.size()-bad.size(),"total":checks.size(),"failed":bad,"checks":checks}
	var file := FileAccess.open("res://docs/tests/p53-architecture-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if bad.is_empty() else 1)
