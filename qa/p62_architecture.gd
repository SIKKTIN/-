extends SceneTree
var checks := {}
var width := 1200
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func shot(label: String) -> void:
	await frame()
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/p62-%d-%s.png" % [width,label])
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): width = int(args[0])
	root.size = Vector2i(width,720 if width == 1200 else 640)
	root.content_scale_size = root.size
	var before := FileAccess.get_sha256("res://data/rooms/r04.json")
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	var c = editor.canvas
	var preview = c.architecture_preview
	checks.runtime_wall_painter_reused = preview.nodes["wall:7"].get_script().resource_path == "res://scripts/presentation/world_volume.gd"
	checks.runtime_roof_painter_reused = preview.nodes["roof:0"].get_script().resource_path == "res://scripts/presentation/roof_building.gd"
	checks.complete_corner_registered = preview.nodes["wall:7"].profile.painted_facade.junctions[0].asset == "cafeteria_turn_l_v28"
	checks.geometry_preview_has_no_simulation = not preview.world.get_property_list().any(func(p): return p.name in ["grid","actors","schedule","navigation_builds"])
	c.zoom = 0.65
	c.origin = c.size/2-Vector2(1030,1260)*c.zoom
	c.queue_redraw()
	await shot("stone-walls")
	var node = preview.nodes["wall:7"]
	var identity: int = node.get_instance_id()
	var ref := {"group":"walls","index":7}
	var original: Rect2 = editor.document.geometry(ref)
	c.choose(ref)
	await frame()
	checks.geometry_selects_textured_wall = c.selection == ref
	checks.visible_front_face_selectable = c.at(c.screen(Vector2(original.get_center().x,original.position.y-45))) == ref
	var point: Vector2 = c.screen(original.get_center())
	for action in range(3):
		var event: InputEvent
		if action == 1:
			event = InputEventMouseMotion.new()
			event.position = point+Vector2(40,20)*c.zoom
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = action == 0
			event.position = point if action == 0 else point+Vector2(40,20)*c.zoom
		c.handle_input(event)
		await frame()
	var moved: Rect2 = editor.document.geometry(ref)
	print("DRAG_GEOMETRY ",original," -> ",moved," painter ",node.footprint)
	checks.real_drag_updates_texture_position = c.selection == ref and moved.position != original.position and node.footprint == moved and preview.world.walls[7] == moved
	checks.drag_reuses_render_node = preview.nodes["wall:7"].get_instance_id() == identity
	editor.document.undo()
	await frame()
	checks.undo_restores_geometry_and_texture = node.footprint == original and editor.document.geometry(ref) == original
	editor.layers.set_visible("architecture",false)
	await frame()
	checks.hidden_wall_layer_disables_hit = not node.visible and not c.at(c.screen(original.get_center())).get("group","") == "walls"
	editor.layers.set_visible("architecture",true)
	await frame()
	checks.show_layer_restores_cached_wall = node.visible
	editor.layers.set_locked("architecture",true)
	checks.locked_wall_not_selectable = c.at(c.screen(original.get_center())).get("group","") != "walls"
	editor.layers.set_locked("architecture",false)
	c.show_collision = true
	c.queue_redraw()
	await shot("collision")
	checks.overlay_above_architecture = c.foreground.z_index > node.z_index
	c.show_collision = false
	editor.document.set_wall_surface(7,100,"cafeteria_wall_front_v23","cafeteria_coping_v23")
	await frame()
	checks.material_edit_updates_shared_preview = preview.nodes["wall:7"].profile.wall_elevation == 100
	editor.document.undo()
	await frame()
	checks.original_map_untouched = FileAccess.get_sha256("res://data/rooms/r04.json") == before
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var report := {"checks":checks,"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed}
	FileAccess.open("res://docs/tests/p62-%d-architecture-native.json" % width,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
