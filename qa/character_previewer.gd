extends SceneTree

const Library = preload("res://scripts/presentation/character_library.gd")
const OUT = "res://docs/dev/character-previewer/"
var checks: Dictionary = {}
var viewer

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks[label] = passed
	if not passed: push_error("FAIL: " + label)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,800)
	viewer = load("res://scenes/editor/character_previewer.tscn").instantiate()
	root.add_child(viewer)
	await process_frame
	viewer.set_process(false)
	Input.warp_mouse(Vector2(5,5))
	check("all production characters listed", viewer.visible_ids.size() == Library.all().size() and viewer.visible_ids.size() == 14)
	for id in Library.all():
		viewer.select_character(id)
		viewer.set_animation(true)
		viewer.set_playing(true)
		var visited: Dictionary = {}
		var stable_feet := true
		for step in range(16):
			viewer.advance(1.0 / float(viewer.asset.walk_animation.fps))
			visited[viewer.frame_index] = true
			stable_feet = stable_feet and absf(viewer.stage.pose_rect(1).end.y) < 1
		check(id + " plays every walk frame", visited.size() == 8)
		check(id + " frame crops and foot anchors match game", stable_feet and viewer.motion == Library.motion(id))
		viewer.set_playing(false)
		var before: float = viewer.frame_clock
		viewer.advance(10)
		check(id + " pause freezes pose", viewer.frame_clock == before)
		viewer.seek_frame(7)
		viewer.next_button.pressed.emit()
		check(id + " next wraps and stays paused", viewer.frame_index == 0 and not viewer.playing)
		viewer.previous_button.pressed.emit()
		check(id + " previous wraps", viewer.frame_index == 7)
		viewer.frame_slider.value = 3
		check(id + " scrub selects matching thumbnail", viewer.frame_index == 3 and viewer.thumbnail_buttons[3].button_pressed)
		viewer.thumbnail_buttons[5].pressed.emit()
		check(id + " thumbnail seeks exact pose", viewer.frame_index == 5 and not viewer.playing)
		viewer.set_direction(true)
		check(id + " flip applies main stage and all poses", viewer.stage.flipped and viewer.thumbnail_canvases.all(func(c): return c.flipped))
		viewer.set_animation(false)
		viewer.advance(1)
		check(id + " idle disables timeline and uses game texture", viewer.frame_index == 0 and viewer.play_button.disabled and not viewer.frame_slider.editable and viewer.stage.pose_texture() == Library.idle(id) and viewer.thumbnail_canvases.size() == 1)
	viewer.select_character("canteen_cook")
	viewer.set_animation(true)
	viewer.seek_frame(0)
	viewer.playback_speed = 0.5
	viewer.set_playing(true)
	viewer.advance(2.0 / 12.0)
	check("half speed advances one frame", viewer.frame_index == 1)
	viewer.playback_speed = 2.0
	viewer.advance(1.0 / 12.0)
	check("double speed advances two frames", viewer.frame_index == 3)
	viewer.search.text = "canteen"
	viewer.search.text_changed.emit(viewer.search.text)
	check("ID search filters list without changing preview", viewer.visible_ids == ["canteen_cook"] and viewer.character_id == "canteen_cook")
	viewer.search.text = "巡逻"
	viewer.search.text_changed.emit(viewer.search.text)
	check("Chinese name search", viewer.visible_ids == ["patrol_guard"])
	viewer.search.text = "no_such_character"
	viewer.search.text_changed.emit(viewer.search.text)
	check("no matches keeps working preview", viewer.visible_ids.is_empty() and viewer.stage.pose_texture() != null)
	viewer.search.text = ""
	viewer.search.text_changed.emit(viewer.search.text)
	viewer.character_list.item_selected.emit(viewer.visible_ids.find("stocky_worker"))
	check("list changes character and resets frame", viewer.character_id == "stocky_worker" and viewer.frame_index == 0)
	viewer.set_direction(false)
	viewer.playback_speed = 1
	viewer.select_character("canteen_cook")
	viewer.seek_frame(2)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_RIGHT
	viewer.search.grab_focus()
	viewer._unhandled_key_input(key)
	check("search input is protected from preview shortcuts", viewer.frame_index == 2)
	viewer.search.release_focus()
	viewer._unhandled_key_input(key)
	check("right shortcut steps pose", viewer.frame_index == 3 and not viewer.playing)
	key.keycode = KEY_SPACE
	viewer._unhandled_key_input(key)
	check("space shortcut resumes animation", viewer.playing)
	viewer.seek_frame(2)
	await process_frame
	await capture("preview-1280")
	root.size = Vector2i(960,640)
	await process_frame
	await process_frame
	check("minimum window stage fits", viewer.stage.get_global_rect().end.x <= 960 and viewer.stage.get_global_rect().end.y <= 640)
	check("minimum window footer and source fit", viewer.source_label.get_global_rect().end.y < 610)
	await capture("preview-960")
	viewer.queue_free()
	await process_frame
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var before: String = JSON.stringify(editor.document.data)
	var dirty: bool = editor.document.dirty()
	editor.operation_bar.get_node("CharacterPreview").pressed.emit()
	await process_frame
	check("editor button opens preview", is_instance_valid(editor.character_preview_window) and editor.character_preview_window.visible)
	var popup = editor.character_preview_window
	popup.get_child(0).select_character("cleaner")
	popup.close_requested.emit()
	editor.open_character_previewer()
	check("editor reuses preview with selection", editor.character_preview_window == popup and popup.get_child(0).character_id == "cleaner")
	check("preview leaves map and dirty state unchanged", before == JSON.stringify(editor.document.data) and dirty == editor.document.dirty())
	editor.queue_free()
	await process_frame
	var failed := checks.values().count(false)
	var report := {"passed": checks.size() - failed, "failed": failed, "checks": checks}
	var output := FileAccess.open(OUT + "checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("Character previewer: ", report.passed, " passed, ", failed, " failed")
	quit(1 if failed else 0)
