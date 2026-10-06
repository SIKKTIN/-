@tool
extends EditorPlugin

var page

func _enter_tree() -> void:
	page = preload("res://scripts/editor/map_editor.gd").new()
	EditorInterface.get_editor_main_screen().add_child(page)
	page.hide()
	if OS.get_environment("ESCAPE_OPEN_MAP_EDITOR") == "1":
		call_deferred("open_page")
	if OS.get_cmdline_user_args().has("--map-editor-qa") or OS.get_cmdline_user_args().has("--map-editor-p51-qa"):
		var probe = load("res://qa/p51_editor_plugin.gd" if OS.get_cmdline_user_args().has("--map-editor-p51-qa") else "res://qa/p50_editor_plugin.gd").new()
		probe.plugin = self
		add_child(probe)

func open_page() -> void:
	EditorInterface.set_main_screen_editor("关卡编辑")

func _exit_tree() -> void:
	if is_instance_valid(page):
		page.canvas.finish_gesture()
		if page.document.dirty():
			# Disabling/reloading a plugin has no cancellable close callback.
			# Retain a recovery copy instead of silently losing the draft.
			print("关卡编辑未保存草稿已保留：",page.document.preview_file())
		page.queue_free()

func _get_unsaved_status(for_scene: String) -> String:
	if for_scene.is_empty() and is_instance_valid(page) and page.has_pending_changes():
		return "关卡编辑有未保存修改："+page.document.path
	return ""

func _apply_changes() -> void:
	if is_instance_valid(page) and page.is_inside_tree():
		page.commit_fields()

func _save_external_data() -> void:
	if is_instance_valid(page) and page.is_inside_tree():
		page.commit_fields()
		if page.document.dirty():
			page.save_current()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "关卡编辑"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("TileMap","EditorIcons")

func _make_visible(visible: bool) -> void:
	if is_instance_valid(page):
		page.visible = visible
		if visible:
			page.canvas.call_deferred("fit")
