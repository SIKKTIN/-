@tool
extends Control

const Document = preload("res://scripts/editor/map_document.gd")
const Canvas = preload("res://scripts/editor/map_canvas.gd")
var document = Document.new()
var canvas
var maps: OptionButton
var asset_picker: OptionButton
var tool_picker: ItemList
var objects: ItemList
var inspector: VBoxContainer
var title_input: LineEdit
var status: Label
var file_label: Label
var validation: AcceptDialog
var unsaved: ConfirmationDialog
var save_as: FileDialog
var pending_path := ""
var selection: Dictionary = {}
var object_refs: Array = []
var refreshing := false
var preview_pid := -1
var preview_path := ""
var preview_button: Button
var undo_button: Button
var redo_button: Button
var tools: Array = ["select","pan","walls","fixtures","patrol","gate_guards","merchants","items","zones","work","meal","dine","free"]
var asset_ids: Array[String] = []
var workspace_root := ""

func has_pending_changes() -> bool:
	if document.dirty(): return true
	if is_instance_valid(title_input) and title_input.text != str(document.data.get("title","")): return true
	if not selection.is_empty():
		var item = document.value(selection)
		if item is Dictionary:
			for property in ["name","id"]:
				var input = inspector.get_node_or_null("Property_"+property)
				if input and input.text != str(item.get(property,"")): return true
	return false

func commit_fields() -> void:
	if not is_inside_tree(): return
	var focus = get_viewport().gui_get_focus_owner()
	if focus and is_ancestor_of(focus): focus.release_focus()
	canvas.finish_gesture()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://art/ui/fullscreen/theme.tres")
	workspace_root = ProjectSettings.globalize_path("res://")
	build_ui()
	document.changed.connect(refresh)
	load_maps()
	request_open("res://data/rooms/r04.json")
	get_window().focus_exited.connect(func(): canvas.finish_gesture())
	if not Engine.is_editor_hint():
		get_window().title = "这次怎么逃 · 关卡编辑器"
		get_window().close_requested.connect(request_quit)
		get_tree().auto_accept_quit = false

func button(parent: Node, label: String, callback: Callable, width := 80) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(width,36)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func label(parent: Node, content: String, font_size := 14) -> Label:
	var l := Label.new()
	l.text = content
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func build_ui() -> void:
	var paper := PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,8)
	paper.add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation",6)
	margin.add_child(root_box)
	var top := HBoxContainer.new()
	root_box.add_child(top)
	label(top,"关卡编辑",21)
	maps = OptionButton.new()
	maps.name = "MapSelector"
	maps.custom_minimum_size.x = 174
	maps.item_selected.connect(func(index): request_open(str(maps.get_item_metadata(index))))
	top.add_child(maps)
	button(top,"重读",func(): request_open(document.path))
	button(top,"保存",save_current)
	button(top,"另存为",func(): save_as.popup_centered(Vector2i(760,500)))
	button(top,"检查地图",check_map,96)
	preview_button = button(top,"▶ 试玩草稿",playtest,120)
	preview_button.name = "Playtest"
	var row := HBoxContainer.new()
	root_box.add_child(row)
	label(row,"名称")
	title_input = LineEdit.new()
	title_input.name = "MapTitle"
	title_input.custom_minimum_size.x = 190
	title_input.text_submitted.connect(func(value): document.begin(); document.data.title = value; document.commit())
	title_input.focus_exited.connect(func():
		if not refreshing and document.data.get("title","") != title_input.text:
			document.begin()
			document.data.title = title_input.text
			document.commit())
	row.add_child(title_input)
	undo_button = button(row,"撤销",func(): commit_fields(); document.undo(); refresh_inspector())
	redo_button = button(row,"重做",func(): commit_fields(); document.redo(); refresh_inspector())
	button(row,"复制",duplicate_selected)
	button(row,"删除",delete_selected)
	button(row,"全图",canvas_fit)
	var snap := CheckButton.new()
	snap.text = "20格吸附"
	snap.button_pressed = true
	snap.toggled.connect(func(on): document.grid = 20 if on else 0)
	row.add_child(snap)
	var collision := CheckButton.new()
	collision.text = "碰撞"
	collision.toggled.connect(func(on): canvas.show_collision = on; canvas.queue_redraw())
	row.add_child(collision)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 176
	split.add_child(left)
	label(left,"放置工具",16)
	tool_picker = ItemList.new()
	tool_picker.name = "ToolPalette"
	tool_picker.custom_minimum_size.y = 180
	tool_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for tool in tools:
		tool_picker.add_item({"select":"选择 / 拖动","pan":"平移视野"}.get(tool,Document.GROUP_NAMES.get(tool,tool)))
	tool_picker.select(0)
	tool_picker.item_selected.connect(func(index):
		canvas.finish_gesture()
		canvas.tool = tools[index]
		show_status("已选 "+tool_picker.get_item_text(index)+"；点击地图放置，墙可拖动绘制。"))
	left.add_child(tool_picker)
	asset_picker = OptionButton.new()
	asset_picker.name = "AssetPicker"
	asset_picker.custom_minimum_size.x = 174
	left.add_child(asset_picker)
	var manifests: Array = ["res://art/props/prison_v08/manifest.json","res://art/props/cafeteria_v14/manifest.json","res://art/props/manifest-v03.json"]
	for manifest_path in manifests:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for asset in manifest.get("assets",[]):
			if str(asset.id) not in asset_ids:
				asset_ids.append(str(asset.id))
				asset_picker.add_item(Document.ASSET_NAMES.get(str(asset.id),str(asset.id)))
	label(left,"地图对象（点击定位）",14)
	objects = ItemList.new()
	objects.name = "ObjectList"
	objects.custom_minimum_size.y = 180
	objects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects.item_selected.connect(func(index):
		canvas.choose(object_refs[index])
		canvas.origin = canvas.size / 2 - document.geometry(object_refs[index]).get_center() * canvas.zoom
		canvas.queue_redraw())
	left.add_child(objects)
	var right_split := HSplitContainer.new()
	split.add_child(right_split)
	canvas = Canvas.new()
	canvas.name = "MapCanvas"
	canvas.custom_minimum_size = Vector2(280,240)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.setup(document)
	canvas.selected.connect(select_object)
	canvas.placed.connect(place_object)
	canvas.edited.connect(refresh_inspector)
	right_split.add_child(canvas)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 234
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_split.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.name = "Properties"
	inspector.custom_minimum_size.x = 218
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)
	file_label = label(root_box,"",12)
	status = label(root_box,"选择对象后拖动；右侧修改尺寸、碰撞和角色归属。",13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 32
	validation = AcceptDialog.new()
	validation.title = "地图检查"
	add_child(validation)
	unsaved = ConfirmationDialog.new()
	unsaved.title = "未保存的地图"
	unsaved.dialog_text = "当前有未保存修改。要放弃修改继续吗？"
	unsaved.get_ok_button().text = "放弃修改"
	unsaved.get_cancel_button().text = "继续编辑"
	unsaved.confirmed.connect(func():
		if pending_path == "__quit":
			get_tree().quit()
		else:
			open_now(pending_path))
	unsaved.canceled.connect(sync_map_choice)
	add_child(unsaved)
	save_as = FileDialog.new()
	save_as.title = "另存为新地图（新的文件名就是地图ID）"
	save_as.access = FileDialog.ACCESS_RESOURCES
	save_as.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_as.current_dir = "res://data/rooms"
	save_as.filters = PackedStringArray(["*.json ; 地图JSON"])
	save_as.file_selected.connect(func(path):
		if document.save_file(path,true):
			load_maps()
			show_status("已保存新地图："+path)
		else:
			show_error(document.last_error))
	add_child(save_as)

func load_maps() -> void:
	maps.clear()
	var files := DirAccess.get_files_at("res://data/rooms")
	for file in files:
		if file.ends_with(".json"):
			maps.add_item(file.get_basename().to_upper())
			maps.set_item_metadata(maps.item_count-1,"res://data/rooms/"+file)
	sync_map_choice()

func sync_map_choice() -> void:
	for index in range(maps.item_count):
		if str(maps.get_item_metadata(index)) == document.path:
			maps.select(index)
			return

func request_open(path: String) -> void:
	commit_fields()
	if document.dirty() and not document.data.is_empty():
		pending_path = path
		unsaved.popup_centered()
	else:
		open_now(path)

func open_now(path: String) -> void:
	if not document.open_file(path):
		show_error(document.last_error)
		return
	selection.clear()
	canvas.selection.clear()
	sync_map_choice()
	refresh_inspector()
	canvas.call_deferred("fit")
	show_status("已打开 "+str(document.data.get("title",document.data.id))+"；修改会留在草稿，保存才写项目地图。")

func canvas_fit() -> void:
	canvas.fit()

func refresh() -> void:
	if not is_instance_valid(file_label):
		return
	refreshing = true
	file_label.text = ("● 未保存  " if document.dirty() else "已保存  ")+document.path
	if not title_input.has_focus():
		title_input.text = str(document.data.get("title",""))
	undo_button.disabled = document.cursor == 0
	redo_button.disabled = document.cursor == document.history.size()
	objects.clear()
	object_refs = document.entries()
	var valid_selection := false
	for index in range(object_refs.size()):
		objects.add_item(document.name_for(object_refs[index]))
		if object_refs[index] == selection:
			objects.select(index)
			valid_selection = true
	if not valid_selection:
		selection.clear()
		canvas.selection.clear()
	refreshing = false

func select_object(ref: Dictionary) -> void:
	selection = ref.duplicate()
	refresh()
	refresh_inspector()

func clear_inspector() -> void:
	var previous_refreshing := refreshing
	refreshing = true
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	refreshing = previous_refreshing

func refresh_inspector() -> void:
	if not inspector:
		return
	clear_inspector()
	if selection.is_empty():
		label(inspector,"对象属性",18)
		var help := label(inspector,"点击地图选择对象。\n\n墙、门、寝室范围可调尺寸。\n伙伴出生点对应自己的寝室。\n巡逻点按列表顺序连接。\n\n试玩直接读取当前草稿。",14)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var ref := selection.duplicate()
	label(inspector,document.name_for(ref),16)
	var rect: Rect2 = document.geometry(ref)
	for field in ["x","y","w","h"] if document.is_rect(ref) else ["x","y"]:
		var row := HBoxContainer.new()
		inspector.add_child(row)
		label(row,{"x":"X位置","y":"Y位置","w":"宽度","h":"高度"}[field])
		var spin := SpinBox.new()
		spin.name = "Geometry_"+field
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.min_value = 1 if field in ["w","h"] else -10000
		spin.max_value = 20000
		spin.step = 1
		spin.value = {"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}[field]
		spin.value_changed.connect(func(value):
			if refreshing: return
			var changed_rect: Rect2 = document.geometry(ref)
			match field:
				"x": changed_rect.position.x = value
				"y": changed_rect.position.y = value
				"w": changed_rect.size.x = value
				"h": changed_rect.size.y = value
			document.begin()
			document.set_geometry(ref,changed_rect)
			document.commit())
		row.add_child(spin)
	var item = document.value(ref)
	if item is Dictionary:
		for property in ["name","id"]:
			if item.has(property):
				label(inspector,"名称" if property == "name" else "对象ID")
				var input := LineEdit.new()
				input.name = "Property_"+property
				input.text = str(item[property])
				input.text_submitted.connect(func(value): document.set_property(ref,property,value))
				input.focus_exited.connect(func():
					if not refreshing: document.set_property(ref,property,input.text))
				inspector.add_child(input)
		if ref.group == "fixtures":
			label(inspector,"摆设样式")
			var appearance := OptionButton.new()
			for asset in asset_ids: appearance.add_item(Document.ASSET_NAMES.get(asset,asset))
			appearance.select(maxi(0,asset_ids.find(str(item.asset_id))))
			appearance.item_selected.connect(func(index): document.set_property(ref,"asset_id",asset_ids[index]); canvas.queue_redraw())
			inspector.add_child(appearance)
			for property in ["blocks_movement","blocks_sight"]:
				var toggle := CheckButton.new()
				toggle.name = property
				toggle.text = "阻挡移动" if property == "blocks_movement" else "阻挡视线"
				toggle.button_pressed = item.get(property,true if property == "blocks_movement" else false)
				toggle.toggled.connect(func(on): document.set_property(ref,property,on))
				inspector.add_child(toggle)
		if ref.group == "dorm_doors":
			label(inspector,"寝室门归属")
			var owner := OptionButton.new()
			for id in range(3): owner.add_item("伙伴%d" % (id+1))
			owner.select(int(item.get("actor_id",0)))
			owner.item_selected.connect(func(id): document.set_property(ref,"actor_id",id))
			inspector.add_child(owner)
		if ref.group == "items":
			var item_type := OptionButton.new()
			var ids := ["scrap","door_key","lock_tool"]
			for id in ids: item_type.add_item({"scrap":"旧零件","door_key":"钥匙","lock_tool":"撬锁工具"}[id])
			item_type.select(maxi(0,ids.find(str(item.definition_id))))
			item_type.item_selected.connect(func(id): document.set_property(ref,"definition_id",ids[id]))
			inspector.add_child(item_type)
	if ref.group in ["starts","dormitories"]:
		label(inspector,"归属：伙伴%d" % (int(ref.index)+1))
	if ref.group == "patrol":
		label(inspector,"巡逻顺序：第%d点" % (int(ref.index)+1))
		button(inspector,"前移巡逻点",func(): reorder_patrol(-1))
		button(inspector,"后移巡逻点",func(): reorder_patrol(1))
	if ref.group == "merchants":
		var note := label(inspector,"移动营业位置时，原地营业与过渡点一起移动；工作和休息位置保留。",12)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(inspector,"所有坐标都使用世界位置。",12)

func reorder_patrol(direction: int) -> void:
	var index: int = selection.index
	var target: int = index+direction
	if target < 0 or target >= document.data.patrol.size():
		return
	document.begin()
	var point = document.data.patrol.pop_at(index)
	document.data.patrol.insert(target,point)
	selection.index = target
	canvas.selection = selection.duplicate()
	document.commit()
	refresh_inspector()

func place_object(group: String, point: Vector2) -> void:
	var asset: String = asset_ids[asset_picker.selected] if group == "fixtures" and not asset_ids.is_empty() else "scrap"
	canvas.choose(document.add(group,point,asset))
	show_status("已添加 "+Document.GROUP_NAMES.get(group,group)+"；可继续放置，或选“选择/拖动”调整。")

func duplicate_selected() -> void:
	commit_fields()
	if not selection.is_empty():
		canvas.choose(document.duplicate_entry(selection))

func delete_selected() -> void:
	commit_fields()
	if document.can_remove(selection):
		document.remove(selection)
		canvas.choose({})
	else:
		show_status("出生点、寝室归属与主门/边界保留；可拖动或修改尺寸。")

func check_map() -> void:
	canvas.finish_gesture()
	var result: Dictionary = document.validate()
	var lines: Array = result.errors.map(func(message): return "错误："+message)
	lines.append_array(result.warnings.map(func(message): return "提示："+message))
	validation.dialog_text = "\n".join(lines) if not lines.is_empty() else "检查通过：坐标、出生点、角色归属与地图边界有效。\n巡逻路径和解谜方案请通过试玩验证。"
	validation.popup_centered(Vector2i(680,360))

func save_current() -> void:
	commit_fields()
	if document.save_file(document.path):
		show_status("已保存；原地图备份为 "+document.path+".bak")
	else:
		show_error(document.last_error)

func playtest() -> void:
	commit_fields()
	if preview_pid > 0 and OS.is_process_running(preview_pid):
		show_status("试玩窗口已经打开；关闭试玩或按F10返回编辑。")
		return
	var result: Dictionary = document.validate()
	if not result.errors.is_empty():
		show_error("试玩前需要修复：\n"+"\n".join(result.errors))
		return
	preview_path = document.preview_file()
	if preview_path == "":
		show_error(document.last_error)
		return
	preview_pid = OS.create_process(OS.get_executable_path(),["--path",workspace_root,"res://scenes/main.tscn","--","--editor-room",preview_path])
	show_status("试玩已打开；F10或关闭试玩返回这里。项目地图未保存，草稿继续保留。" if preview_pid > 0 else "试玩启动失败，请检查Godot可执行文件。")

func show_status(message: String) -> void:
	status.text = message

func show_error(message: String) -> void:
	show_status(message)
	validation.title = "需要处理"
	validation.dialog_text = message
	validation.popup_centered(Vector2i(680,360))

func request_quit() -> void:
	commit_fields()
	if document.dirty():
		pending_path = "__quit"
		unsaved.popup_centered()
	else:
		get_tree().quit()

func _process(_delta: float) -> void:
	if preview_pid > 0 and not OS.is_process_running(preview_pid):
		preview_pid = -1
		if FileAccess.file_exists(preview_path):
			DirAccess.remove_absolute(preview_path)
		show_status("已返回编辑；试玩副本已清理，草稿和撤销历史保留。")

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or validation.visible or save_as.visible or unsaved.visible:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		canvas.finish_gesture()
		if event.shift_pressed: document.redo()
		else: document.undo()
		refresh_inspector()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		document.redo()
		refresh_inspector()
	elif event.ctrl_pressed and event.keycode == KEY_S:
		save_current()
	elif event.ctrl_pressed and event.keycode == KEY_D:
		duplicate_selected()
	elif event.keycode == KEY_DELETE:
		delete_selected()
	elif event.keycode == KEY_F:
		canvas.fit()
	elif event.keycode == KEY_ESCAPE:
		canvas.finish_gesture(true)
		canvas.choose({})
	else:
		return
	get_viewport().set_input_as_handled()
