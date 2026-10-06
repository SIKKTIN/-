extends SceneTree

var checks := {}
var editor
var native := false
var width := 1280
var before_map_hash := ""

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	if native: await RenderingServer.frame_post_draw

func mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*point
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
	await frame()

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)
	await frame()

func shot(label: String) -> void:
	if native:
		await frame()
		root.get_texture().get_image().save_png("res://docs/tests/p50-editor-%d-%s.png" % [width,label])

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	width = int(args[0]) if not args.is_empty() else 1280
	root.content_scale_size = Vector2i(width,640 if width == 960 else 800)
	root.size = root.content_scale_size
	before_map_hash = FileAccess.get_sha256("res://data/rooms/r04.json")
	editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.canvas.fit()
	var d = editor.document
	checks.loaded_r04 = d.data.id == "r04" and editor.maps.item_count >= 4
	checks.all_existing_maps_compatible = true
	for identifier in ["r01","r02","r03","r04"]:
		checks.all_existing_maps_compatible = checks.all_existing_maps_compatible and d.open_file("res://data/rooms/"+identifier+".json") and not d.dirty() and d.validate().errors.is_empty()
	editor.canvas.fit()
	checks.furniture_loaded = editor.canvas.textures.size() > 10
	checks.embed_dormitories = d.data.dormitories.size() == 3
	checks.initial_clean = not d.dirty()
	var result: Dictionary = d.validate()
	print("BASELINE_VALIDATION ",JSON.stringify(result))
	checks.r04_can_save_and_preview = result.errors.is_empty()
	checks.canvas_visible = editor.canvas.size.x >= 280 and editor.canvas.size.y >= 240
	checks.right_inspector_visible = root.get_visible_rect().encloses(editor.inspector.get_global_rect())
	await shot("layout")
	# Work point near open space is selected and moved through the actual canvas.
	var ref := {"group":"work","index":0}
	var before: Vector2 = d.geometry(ref).position
	var start: Vector2 = editor.canvas.global_position+editor.canvas.screen(before)
	# Target a grid center. At 15% overview scale an existing half-grid point
	# otherwise lands on a rounding tie after native pixel input conversion.
	var target: Vector2 = d.snap_point(before)+Vector2(40,40)
	var end: Vector2 = editor.canvas.global_position+editor.canvas.screen(target)
	await mouse(start,true)
	checks.click_selects_work_point = editor.selection == ref
	await motion(end)
	await mouse(end,false)
	checks.drag_snaps_actual_input = d.geometry(ref).position.distance_to(target) < 1
	checks.drag_one_undo = d.history.size() == 1 and d.cursor == 1
	d.undo()
	checks.undo_restores_original = d.geometry(ref).position == before
	d.redo()
	checks.redo_restores_move = d.geometry(ref).position != before
	d.undo()
	# Selecting a fixture exposes actual flags and geometry.
	var fixture := {"group":"fixtures","index":0}
	editor.canvas.choose(fixture)
	await frame()
	checks.inspector_has_collision_flags = editor.inspector.has_node("blocks_movement") and editor.inspector.has_node("blocks_sight")
	var toggle: CheckButton = editor.inspector.get_node("blocks_sight")
	var toggle_point := toggle.get_global_rect().get_center()
	await mouse(toggle_point,true)
	await mouse(toggle_point,false)
	checks.inspector_real_toggle = d.value(fixture).blocks_sight == true
	d.undo()
	checks.inspector_change_undo = not d.value(fixture).blocks_sight
	var duplicated: Dictionary = d.duplicate_entry(fixture)
	checks.duplicate_unique_id = d.value(duplicated).id != d.value(fixture).id and d.geometry(duplicated).position == d.geometry(fixture).position+Vector2(40,40)
	d.remove(duplicated)
	checks.delete_duplicate = d.collection("fixtures").size() == JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/r04.json")).fixtures.size()
	checks.protect_three_spawns = not d.can_remove({"group":"starts","index":0})
	var new_tray: Dictionary = d.add("fixtures",Vector2(1360,1660),"cafeteria_tray")
	checks.add_prop_keeps_nonblocking_template = d.geometry(new_tray).size == Vector2(36,20) and not d.value(new_tray).blocks_movement
	var tray_before: float = d.value(new_tray).draw_depth
	d.begin()
	d.move(new_tray,d.geometry(new_tray).position+Vector2(0,40))
	d.commit()
	checks.tabletop_draw_depth_moves_with_prop = d.value(new_tray).draw_depth == tray_before+40
	d.undo()
	d.undo()
	# Draw a wall in open space. This is intentionally a draft, not the source map.
	editor.canvas.tool = "walls"
	var wall_count: int = d.data.walls.size()
	var p: Vector2 = editor.canvas.global_position+editor.canvas.screen(Vector2(1300,700))
	await mouse(p,true)
	await motion(p+Vector2(160,20)*editor.canvas.zoom)
	await mouse(p+Vector2(160,20)*editor.canvas.zoom,false)
	checks.draw_wall_real_input = d.data.walls.size() == wall_count+1 and d.geometry(editor.selection).size.x >= 140
	d.undo()
	checks.wall_one_undo = d.data.walls.size() == wall_count
	editor.canvas.tool = "select"
	# Patrol order changes are undoable and shown as connected route segments.
	editor.canvas.choose({"group":"patrol","index":0})
	var patrol_before: Array = d.data.patrol.duplicate(true)
	editor.reorder_patrol(1)
	checks.patrol_reorder = d.data.patrol[1] == patrol_before[0]
	d.undo()
	checks.patrol_reorder_undo = d.data.patrol == patrol_before
	# Merchant office location and matching shop/commute points move together.
	var merchant := {"group":"merchants","index":0}
	var merchant_before: Dictionary = d.value(merchant).duplicate(true)
	d.begin()
	d.move(merchant,d.geometry(merchant).position+Vector2(0,40))
	d.commit()
	checks.shop_schedule_follows_new_position = d.value(merchant).routine.filter(func(entry): return entry.kind == "shop").all(func(entry): return entry.position == d.value(merchant).position)
	checks.merchant_other_routine_preserved = d.value(merchant).routine[0].position == merchant_before.routine[0].position
	d.undo()
	# Refuse bad geometry and malformed input before writing or rendering.
	d.begin()
	d.set_geometry({"group":"starts","index":0},Rect2(Vector2(600,200),Vector2.ZERO))
	d.commit()
	checks.blocked_spawn_reported = not d.validate().errors.is_empty()
	d.undo()
	var bad_path := "user://p50-invalid.json"
	FileAccess.open(bad_path,FileAccess.WRITE).store_string('{"id":"bad","bounds":[1,2],"starts":[]}')
	checks.invalid_json_preserves_current_draft = not d.open_file(bad_path) and d.data.id == "r04"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	# Save only an isolated QA room; preserve custom unknown data exactly.
	var qa_path := "res://data/rooms/p50_qa.json"
	checks.restricted_save_path = not d.save_file("res://art/not-a-map.json",true)
	d.data.qa_unknown_field = {"nested":["keep",123]}
	checks.save_new_file = d.save_file(qa_path,true)
	checks.rename_id_matches_file = d.data.id == "p50_qa"
	checks.save_clears_dirty = not d.dirty()
	checks.save_as_clears_source_identity_history = d.cursor == 0 and d.history.is_empty()
	var saved: String = d.text()
	checks.reopen_saved = d.open_file(qa_path)
	checks.roundtrip_unknown_fields = d.data == JSON.parse_string(saved) and d.data.qa_unknown_field.nested[0] == "keep" and d.data.qa_unknown_field.nested[1] == 123
	d.begin()
	d.data.title = "QA修改标题"
	d.commit()
	checks.update_existing_with_backup = d.save_file(qa_path) and FileAccess.file_exists(qa_path+".bak")
	checks.backup_holds_previous_map = JSON.parse_string(FileAccess.get_file_as_string(qa_path+".bak")).title != "QA修改标题"
	var external: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(qa_path))
	external.title = "外部修改"
	var external_file := FileAccess.open(qa_path,FileAccess.WRITE)
	external_file.store_string(JSON.stringify(external))
	external_file.close()
	d.begin()
	d.data.title = "不覆盖外部版本"
	d.commit()
	checks.external_change_not_overwritten = not d.save_file(qa_path) and JSON.parse_string(FileAccess.get_file_as_string(qa_path)).title == "外部修改"
	var preview_path: String = d.preview_file()
	checks.preview_temp_file = FileAccess.file_exists(preview_path)
	checks.preview_keeps_unsaved_data = JSON.parse_string(FileAccess.get_file_as_string(preview_path)).title == "不覆盖外部版本" and d.dirty()
	DirAccess.remove_absolute(preview_path)
	for suffix in ["",".bak",".writing"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_path+suffix))
	# Unsaved switching asks rather than silently discarding, cancel leaves draft.
	editor.request_open("res://data/rooms/r01.json")
	checks.unsaved_map_switch_prompts = editor.unsaved.visible and d.data.id == "p50_qa"
	editor.unsaved.hide()
	editor.open_now("res://data/rooms/r04.json")
	editor.canvas.choose({"group":"dormitories","index":0})
	await frame()
	await shot("dormitory")
	checks.source_r04_unchanged = FileAccess.get_sha256("res://data/rooms/r04.json") == before_map_hash
	if native:
		# Launch the actual main scene from the real toolbar, then return with
		# this QA-owned child process closed. Runtime F10 is checked separately.
		editor.canvas.choose({})
		d.begin()
		d.data.title = "未保存的试玩草稿"
		d.commit()
		var draft_before: String = d.text()
		var history_before: int = d.cursor
		await mouse(editor.preview_button.get_global_rect().get_center(),true)
		await mouse(editor.preview_button.get_global_rect().get_center(),false)
		for index in range(60): await frame()
		var child_pid: int = editor.preview_pid
		checks.toolbar_launches_actual_game = child_pid > 0 and OS.is_process_running(child_pid)
		var child_file: String = editor.preview_path
		checks.playtest_uses_unsaved_snapshot = FileAccess.file_exists(child_file) and JSON.parse_string(FileAccess.get_file_as_string(child_file)).title == "未保存的试玩草稿"
		if child_pid > 0 and OS.is_process_running(child_pid): OS.kill(child_pid)
		for index in range(120):
			await frame()
			if editor.preview_pid < 0: break
		checks.return_preserves_draft_history = editor.preview_pid < 0 and d.text() == draft_before and d.cursor == history_before
		checks.return_removes_preview_file = not FileAccess.file_exists(child_file)
		checks.playtest_never_saves_source = FileAccess.get_sha256("res://data/rooms/r04.json") == before_map_hash
		root.grab_focus()
		editor.open_now("res://data/rooms/r04.json")
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p50-editor-%s-%d.json" % ["native" if native else "headless",width],FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Actual editor scene with real Input.parse_input_event mouse routing; isolated QA map save/backup/roundtrip/conflict; original R04 hash protected.","native":native,"width":width},"\t")+"\n")
	print("P50_EDITOR passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(key): return not checks[key]))
	editor.queue_free()
	await frame()
	quit(0 if passed else 1)
