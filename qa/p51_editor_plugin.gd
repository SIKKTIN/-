@tool
extends Node

var plugin
var checks := {}

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.ctrl_pressed = true
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frame()
	event.pressed = false
	Input.parse_input_event(event)
	await frame()

func run() -> void:
	for index in range(35): await frame()
	plugin.open_page()
	for index in range(5): await frame()
	var page = plugin.page
	var document = page.document
	var source_hash := FileAccess.get_sha256("res://data/rooms/r04.json")
	checks.actual_editor_hint = Engine.is_editor_hint()
	checks.actual_main_screen = page.get_parent() == EditorInterface.get_editor_main_screen()
	checks.main_page_visible = page.is_visible_in_tree() and page.size.x >= 690
	checks.open_r04_clean = document.data.id == "r04" and not page.has_pending_changes()
	checks.close_clean_no_prompt = plugin._get_unsaved_status("") == ""
	checks.operation_and_resource_pages = page.operation_buttons.size() == 3 and page.palette.item_count >= 7 and page.catalog.paired_icons == 14
	var before_view_change: String = document.text()
	page.layers.preset("all")
	page.layers.set_locked("items",true)
	page.layers.preset("scene")
	checks.view_layers_keep_document_clean = document.text() == before_view_change and not document.dirty()
	page.layers.set_locked("items",false)
	page.title_input.grab_focus()
	page.title_input.text = "未提交字段草稿"
	checks.pending_field_prompts_on_close = plugin._get_unsaved_status("") != ""
	plugin._apply_changes()
	checks.apply_commits_focused_field = document.data.title == "未提交字段草稿" and document.dirty()
	checks.unrelated_scene_close_no_prompt = plugin._get_unsaved_status("res://scenes/main.tscn") == ""
	var qa_path := "res://data/rooms/p51_plugin_qa.json"
	checks.isolated_save_as = document.save_file(qa_path,true)
	document.begin()
	document.data.title = "编辑器外部资源保存"
	document.commit()
	await key(KEY_Z)
	checks.editor_keyboard_undo = document.data.title == "未提交字段草稿" and document.data.id == "p51_plugin_qa"
	await key(KEY_Y)
	checks.editor_keyboard_redo = document.data.title == "编辑器外部资源保存"
	plugin._save_external_data()
	checks.editor_save_external_map = not document.dirty() and JSON.parse_string(FileAccess.get_file_as_string(qa_path)).title == "编辑器外部资源保存"
	checks.editor_save_backup = FileAccess.file_exists(qa_path+".bak")
	page.open_now("res://data/rooms/r04.json")
	page.canvas.choose({"group":"dormitories","index":0})
	for index in range(4): await frame()
	checks.source_map_untouched = FileAccess.get_sha256("res://data/rooms/r04.json") == source_hash
	checks.finished_clean = plugin._get_unsaved_status("") == ""
	var native := DisplayServer.get_name() != "headless"
	if native:
		var screenshot: Image = page.get_viewport().get_texture().get_image()
		screenshot.save_png("res://docs/tests/p51-editor-plugin.png")
		page.playtest()
		for index in range(60): await frame()
		var pid: int = page.preview_pid
		var preview_path: String = page.preview_path
		checks.editor_launches_actual_game = pid > 0 and OS.is_process_running(pid)
		checks.editor_isolated_preview = FileAccess.file_exists(preview_path) and JSON.parse_string(FileAccess.get_file_as_string(preview_path)).id == "r04"
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
		for index in range(120):
			await frame()
			if page.preview_pid < 0: break
		checks.editor_return_preserves_clean_map = page.preview_pid < 0 and not document.dirty()
		checks.editor_removes_temp_preview = not FileAccess.file_exists(preview_path)
	for suffix in ["",".bak",".writing"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(qa_path+suffix))
	var passed: bool = checks.values().all(func(value): return value)
	FileAccess.open("res://docs/tests/p51-editor-plugin-"+("native" if native else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"native":native,"scope":"Actual Godot editor loads enabled plugin; EditorInterface main-screen page plus global unsaved/apply/save callbacks on isolated QA map; source R04 preserved."},"\t")+"\n")
	print("P51_EDITOR_PLUGIN passed=",passed," count=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	get_tree().quit(0 if passed else 1)
