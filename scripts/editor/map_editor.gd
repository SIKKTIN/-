@tool
extends Control

const Document = preload("res://scripts/editor/map_document.gd")
const Canvas = preload("res://scripts/editor/map_canvas.gd")
const Layers = preload("res://scripts/editor/map_layers.gd")
const Catalog = preload("res://scripts/editor/editor_catalog.gd")
var document = Document.new()
var layers = Layers.new()
var catalog = Catalog.new()
var canvas
var maps: OptionButton
var palette: ItemList
var category_picker: OptionButton
var subcategory_picker: OptionButton
var resource_search: LineEdit
var resource_count: Label
var subcategory_ids: Array[String] = []
var remembered_subcategories: Dictionary = {}
var object_filter: OptionButton
var library_tabs: TabContainer
var operation_bar: HFlowContainer
var operation_buttons: Dictionary = {}
var active_tool: Label
var layer_rows: Dictionary = {}
var palette_entries: Array[Dictionary] = []
var placement: Dictionary = {}
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
	layers.changed.connect(on_layers_changed)
	load_maps()
	request_open("res://data/rooms/r04.json")
	get_window().focus_exited.connect(func(): canvas.finish_gesture())
	if not Engine.is_editor_hint():
		get_window().title = "监狱风云 · 关卡编辑器 · 统一建筑素材"
		get_window().close_requested.connect(request_quit)
		get_tree().auto_accept_quit = false

func button(parent: Node, label: String, callback: Callable, width := 80) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size",14)
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
	label(top,"关卡编辑",19)
	maps = OptionButton.new()
	maps.name = "MapSelector"
	maps.custom_minimum_size.x = 96
	maps.add_theme_font_size_override("font_size",14)
	maps.item_selected.connect(func(index): request_open(str(maps.get_item_metadata(index))))
	top.add_child(maps)
	title_input = LineEdit.new()
	title_input.name = "MapTitle"
	title_input.custom_minimum_size.x = 140
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_input.add_theme_font_size_override("font_size",14)
	title_input.tooltip_text = "地图名称"
	title_input.text_submitted.connect(func(value): document.begin(); document.data.title = value; document.commit())
	title_input.focus_exited.connect(func():
		if not refreshing and document.data.get("title","") != title_input.text:
			document.begin()
			document.data.title = title_input.text
			document.commit())
	top.add_child(title_input)
	button(top,"重读",func(): request_open(document.path),56)
	button(top,"保存",save_current,56)
	button(top,"另存为",func(): commit_fields(); save_as.popup_centered(Vector2i(760,500)),68)
	button(top,"检查地图",check_map,80)
	preview_button = button(top,"▶ 试玩草稿",playtest,112)
	preview_button.name = "Playtest"
	operation_bar = HFlowContainer.new()
	operation_bar.name = "Operations"
	root_box.add_child(operation_bar)
	for mode in ["select","pan","walls"]:
		var mode_button := button(operation_bar,{"select":"选择 V","pan":"平移 H","walls":"绘墙 B"}[mode],func(): set_tool(mode),90)
		mode_button.name = "Tool_"+mode
		mode_button.icon = catalog.icon({"id":mode,"icon":catalog.tool_icons.get(mode,"")})
		mode_button.expand_icon = true
		mode_button.add_theme_constant_override("icon_max_width",18)
		mode_button.toggle_mode = true
		operation_buttons[mode] = mode_button
	undo_button = button(operation_bar,"撤销",func(): commit_fields(); document.undo(); refresh_inspector(),56)
	redo_button = button(operation_bar,"重做",func(): commit_fields(); document.redo(); refresh_inspector(),56)
	button(operation_bar,"复制",duplicate_selected,56)
	button(operation_bar,"删除",delete_selected,56)
	button(operation_bar,"全图",canvas_fit,56)
	var snap := CheckButton.new()
	snap.text = "20格吸附"
	snap.add_theme_font_size_override("font_size",13)
	snap.button_pressed = true
	snap.toggled.connect(func(on): document.grid = 20 if on else 0)
	operation_bar.add_child(snap)
	var collision := CheckButton.new()
	collision.text = "碰撞"
	collision.add_theme_font_size_override("font_size",13)
	collision.toggled.connect(func(on): canvas.show_collision = on; canvas.queue_redraw())
	operation_bar.add_child(collision)
	active_tool = label(operation_bar,"选择对象",13)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)
	library_tabs = TabContainer.new()
	library_tabs.name = "Library"
	library_tabs.custom_minimum_size.x = 242
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = Color("f1eadb")
	for edge in ["left","right","top","bottom"]: tab_panel.set_content_margin(int({"left":0,"top":1,"right":2,"bottom":3}[edge]),6)
	library_tabs.add_theme_stylebox_override("panel",tab_panel)
	var tab_bar := library_tabs.get_tab_bar()
	tab_bar.add_theme_font_size_override("font_size",14)
	for style in ["tab_selected","tab_unselected","tab_hovered"]:
		var tab := StyleBoxFlat.new()
		tab.bg_color = Color("e4f1e9") if style == "tab_selected" else Color("e5dfd1")
		tab.set_corner_radius_all(5)
		tab.set_content_margin_all(8)
		tab_bar.add_theme_stylebox_override(style,tab)
	tab_bar.add_theme_color_override("font_selected_color",Color("2c3e47"))
	tab_bar.add_theme_color_override("font_unselected_color",Color("52615e"))
	split.add_child(library_tabs)
	var resources := VBoxContainer.new()
	resources.name = "素材"
	library_tabs.add_child(resources)
	category_picker = OptionButton.new()
	category_picker.name = "ResourceCategory"
	category_picker.add_theme_font_size_override("font_size",14)
	for category in Catalog.CATEGORIES: category_picker.add_item(Catalog.CATEGORY_NAMES[category])
	category_picker.item_selected.connect(func(_index): rebuild_subcategories())
	category_picker.tooltip_text = "一级分类"
	resources.add_child(category_picker)
	subcategory_picker = OptionButton.new()
	subcategory_picker.name = "ResourceSubcategory"
	subcategory_picker.tooltip_text = "二级分类：按部件用途查找"
	subcategory_picker.add_theme_font_size_override("font_size",14)
	subcategory_picker.item_selected.connect(func(index):
		remembered_subcategories[Catalog.CATEGORIES[category_picker.selected]] = subcategory_ids[index]
		rebuild_palette())
	resources.add_child(subcategory_picker)
	resource_search = LineEdit.new()
	resource_search.name = "ResourceSearch"
	resource_search.placeholder_text = "搜索名称 / 素材ID"
	resource_search.tooltip_text = "在当前二级分类中搜索；选择全部类型可搜索整个主分类。"
	resource_search.clear_button_enabled = true
	resource_search.add_theme_font_size_override("font_size",13)
	resource_search.text_changed.connect(func(_text): rebuild_palette())
	resources.add_child(resource_search)
	resource_count = label(resources,"",12)
	resource_count.name = "ResourceCount"
	resource_count.modulate = Color("52615e")
	palette = ItemList.new()
	palette.name = "ResourceCards"
	palette.max_columns = 2
	palette.same_column_width = true
	palette.fixed_column_width = 90
	palette.max_text_lines = 2
	palette.fixed_icon_size = Vector2i(48,48)
	palette.icon_mode = ItemList.ICON_MODE_TOP
	palette.add_theme_font_size_override("font_size",13)
	palette.add_theme_constant_override("v_separation",10)
	palette.add_theme_constant_override("h_separation",6)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.item_selected.connect(func(index): activate_resource(palette_entries[index]))
	resources.add_child(palette)
	var palette_help := label(resources,"选素材，再点击地图放置。\nEsc取消；绘墙使用顶部工具。",12)
	palette_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var object_tab := VBoxContainer.new()
	object_tab.name = "对象"
	library_tabs.add_child(object_tab)
	object_filter = OptionButton.new()
	object_filter.tooltip_text = "仅列出可见图层；隐藏层请先在右侧打开眼睛。"
	object_filter.add_theme_font_size_override("font_size",14)
	object_filter.add_item("所有可见图层")
	for key in Layers.ORDER: object_filter.add_item(Layers.NAMES[key])
	object_filter.item_selected.connect(func(_index): refresh())
	object_tab.add_child(object_filter)
	objects = ItemList.new()
	objects.name = "ObjectList"
	objects.add_theme_font_size_override("font_size",14)
	objects.size_flags_vertical = Control.SIZE_EXPAND_FILL
	objects.item_selected.connect(func(index):
		commit_fields()
		canvas.choose(object_refs[index])
		canvas.origin = canvas.size / 2 - document.geometry(object_refs[index]).get_center() * canvas.zoom
		canvas.queue_redraw())
	object_tab.add_child(objects)
	var right_split := HSplitContainer.new()
	split.add_child(right_split)
	canvas = Canvas.new()
	canvas.name = "MapCanvas"
	canvas.custom_minimum_size = Vector2(280,240)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.setup(document,layers)
	canvas.selected.connect(select_object)
	canvas.placed.connect(place_object)
	canvas.edited.connect(refresh_inspector)
	canvas.blocked.connect(show_status)
	canvas.interaction_started.connect(commit_fields)
	right_split.add_child(canvas)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 234
	right_split.add_child(side)
	build_layers(side)
	side.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
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
		commit_fields()
		if document.save_file(path,true):
			load_maps()
			show_status("已保存新地图："+path)
		else:
			show_error(document.last_error))
	add_child(save_as)
	rebuild_subcategories()
	set_tool("select")

func build_layers(parent: Node) -> void:
	var heading := HBoxContainer.new()
	parent.add_child(heading)
	var body := VBoxContainer.new()
	var fold: Button
	fold = button(heading,"图层 ▾",func(): body.visible = not body.visible; fold.text = "图层 ▾" if body.visible else "图层 ▸",64)
	button(heading,"场景",func(): commit_fields(); layers.preset("scene"),48)
	button(heading,"全部",func(): commit_fields(); layers.preset("all"),48)
	button(heading,"独显",solo_layer,48)
	parent.add_child(body)
	for key in Layers.ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",2)
		body.add_child(row)
		var name_label := label(row,Layers.NAMES[key],12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var visibility := CheckBox.new()
		visibility.name = "Visible_"+key
		visibility.text = "显"
		if catalog.tool_icons.has("eye"):
			visibility.text = ""
			visibility.icon = catalog.icon({"id":"eye","icon":catalog.tool_icons.eye})
			visibility.expand_icon = true
			visibility.add_theme_constant_override("icon_max_width",16)
			visibility.custom_minimum_size.x = 54
		visibility.tooltip_text = "显示/隐藏本图层；隐藏对象不会被删除或选中。"
		visibility.add_theme_font_size_override("font_size",12)
		visibility.button_pressed = layers.visible[key]
		visibility.toggled.connect(func(value): commit_fields(); layers.set_visible(key,value))
		row.add_child(visibility)
		var lock := CheckBox.new()
		lock.name = "Locked_"+key
		lock.text = "锁"
		if catalog.tool_icons.has("lock"):
			lock.text = ""
			lock.icon = catalog.icon({"id":"lock","icon":catalog.tool_icons.lock})
			lock.expand_icon = true
			lock.add_theme_constant_override("icon_max_width",16)
			lock.custom_minimum_size.x = 54
		lock.tooltip_text = "锁定后可见，但不能点选、移动或放置本层对象。"
		lock.add_theme_font_size_override("font_size",12)
		lock.button_pressed = layers.locked[key]
		lock.toggled.connect(func(value): commit_fields(); layers.set_locked(key,value))
		row.add_child(lock)
		layer_rows[key] = {"name":name_label,"visible":visibility,"locked":lock}
	var help := label(body,"眼睛：显示  ·  锁：禁止编辑",11)
	help.modulate = Color("6d807b")

func rebuild_subcategories() -> void:
	var category: String = Catalog.CATEGORIES[category_picker.selected]
	subcategory_ids = catalog.subcategories(category)
	subcategory_picker.clear()
	for id in subcategory_ids:
		var count := catalog.filtered_entries(category,id).size()
		subcategory_picker.add_item("%s (%d)" % [Catalog.SUBCATEGORY_NAMES[id],count])
	var preferred: String = remembered_subcategories.get(category,"furnishings" if category == "furniture" else "all")
	var index := subcategory_ids.find(preferred)
	subcategory_picker.select(maxi(0,index))
	rebuild_palette()

func rebuild_palette() -> void:
	if not is_instance_valid(palette) or subcategory_ids.is_empty(): return
	palette.clear()
	palette_entries.clear()
	var category: String = Catalog.CATEGORIES[category_picker.selected]
	var subcategory: String = subcategory_ids[subcategory_picker.selected]
	palette_entries = catalog.filtered_entries(category,subcategory,resource_search.text)
	for entry in palette_entries:
		var index := palette.add_item(str(entry.name),catalog.icon(entry))
		palette.set_item_tooltip(index,"%s / %s\n%s\n%s" % [Catalog.CATEGORY_NAMES[category],Catalog.SUBCATEGORY_NAMES[entry.subcategory],entry.name,entry.id])
		palette.set_item_disabled(index,layers.locked[layers.key_for(entry.group)])
		if not placement.is_empty() and entry.id == placement.id: palette.select(index)
	resource_count.text = "找到 %d 个素材" % palette_entries.size() if not palette_entries.is_empty() else "没有匹配素材，试试全部类型。"

func set_tool(mode: String) -> void:
	commit_fields()
	placement.clear()
	if is_instance_valid(canvas):
		if mode == "walls" and layers.locked.architecture:
			show_status("墙门 / 机关图层已锁定，请先解锁。")
			mode = "select"
		elif mode == "walls" and not layers.visible.architecture:
			layers.set_visible("architecture",true)
		canvas.tool = mode
	for key in operation_buttons: operation_buttons[key].set_pressed_no_signal(key == mode)
	if is_instance_valid(palette): palette.deselect_all()
	active_tool.text = {"select":"选择对象","pan":"平移视野","walls":"绘制墙体"}.get(mode,mode)

func activate_resource(entry: Dictionary) -> void:
	commit_fields()
	var key: String = layers.key_for(entry.group)
	if layers.locked[key]:
		show_status(Layers.NAMES[key]+"已锁定，请先解锁。")
		return
	if not layers.visible[key]: layers.set_visible(key,true)
	placement = entry.duplicate()
	canvas.tool = str(entry.group)
	for index in range(palette_entries.size()):
		if palette_entries[index].id == entry.id: palette.select(index)
	for control in operation_buttons.values(): control.set_pressed_no_signal(false)
	active_tool.text = "放置："+str(entry.name)
	show_status("已选“"+str(entry.name)+"”，点击地图放置；V切回选择，Esc取消。")

func solo_layer() -> void:
	commit_fields()
	var key: String = layers.key_for(selection.group) if not selection.is_empty() else layers.key_for(placement.group) if not placement.is_empty() else "architecture"
	layers.preset("solo",key)

func on_layers_changed() -> void:
	if not is_instance_valid(canvas): return
	canvas.finish_gesture()
	if not selection.is_empty() and not layers.is_editable(selection.group): canvas.choose({})
	if not placement.is_empty() and not layers.is_editable(placement.group): set_tool("select")
	if canvas.tool == "walls" and not layers.is_editable("walls"): set_tool("select")
	canvas.queue_redraw()
	rebuild_palette()
	refresh()
	refresh_inspector()

func can_edit_selection() -> bool:
	return not selection.is_empty() and layers.is_editable(selection.group)

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
	object_refs.clear()
	var all_refs: Array = document.entries()
	var valid_selection: bool = selection in all_refs and not selection.is_empty() and layers.is_editable(selection.group)
	var counts := {}
	for key in Layers.ORDER: counts[key] = 0
	for ref in all_refs:
		var key: String = layers.key_for(ref.group)
		counts[key] += 1
		if not layers.is_visible(ref.group): continue
		if object_filter.selected > 0 and key != Layers.ORDER[object_filter.selected-1]: continue
		object_refs.append(ref)
		var index := objects.add_item(("锁 · " if layers.locked[key] else "")+document.name_for(ref))
		objects.set_item_disabled(index,layers.locked[key])
		if ref == selection: objects.select(index)
	for key in layer_rows:
		layer_rows[key].name.text = Layers.NAMES[key]+"  "+str(counts[key])
		layer_rows[key].visible.set_pressed_no_signal(layers.visible[key])
		layer_rows[key].locked.set_pressed_no_signal(layers.locked[key])
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
			if refreshing or not can_edit_selection(): return
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
	if ref.group == "walls":
		label(inspector,"建筑显示高度",13)
		var height := SpinBox.new()
		height.name = "WallElevation"
		height.min_value = 18
		height.max_value = 200
		height.value = document.wall_surface(int(ref.index)).get("height",24 if rect.size.x > 60 else 18)
		height.value_changed.connect(func(value):
			if refreshing: return
			document.set_wall_surface(int(ref.index),value))
		inspector.add_child(height)
		var wall_material := OptionButton.new()
		wall_material.name = "WallMaterial"
		wall_material.add_theme_constant_override("icon_max_width",24)
		wall_material.add_icon_item(catalog.icon({"id":"cafeteria_wall_front_v23","icon":catalog.assets.get("cafeteria_wall_front_v23",{}).get("editor_icon","")}),"食堂 · 浅色高墙")
		wall_material.add_icon_item(catalog.icon({"id":"solitary_wall_front_v23","icon":catalog.assets.get("solitary_wall_front_v23",{}).get("editor_icon","")}),"禁闭 · 深灰厚墙")
		wall_material.select(1 if document.wall_surface(int(ref.index)).get("front","") == "solitary_wall_front_v23" else 0)
		wall_material.item_selected.connect(func(index):
			document.set_wall_surface(int(ref.index),height.value,"cafeteria_wall_front_v23" if index == 0 else "solitary_wall_front_v23","cafeteria_coping_v23" if index == 0 else "solitary_coping_v23"))
		inspector.add_child(wall_material)
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
		if ref.group == "visibility_rooms":
			label(inspector,"屋顶样式",13)
			var roofs := OptionButton.new()
			roofs.name = "RoofStyle"
			roofs.add_theme_constant_override("icon_max_width",24)
			roofs.add_item("按建筑自动选择")
			var roof_ids := ["concrete","dark_concrete","metal_green","metal_light"]
			var roof_names := ["寝室 · 混凝土","禁闭室 · 深灰平顶","车间 / 仓库 · 灰绿金属","食堂 · 浅灰金属"]
			var roof_assets := ["roof_concrete_warm","roof_concrete_dark","roof_metal_green","roof_metal_light"]
			for index in range(roof_ids.size()):
				roofs.add_icon_item(load("res://art/editor/room_roofs_v47/"+roof_assets[index]+".tres"),roof_names[index])
			roofs.get_popup().set("theme_override_constants/icon_max_width",24)
			roofs.select(roof_ids.find(str(item.get("roof_style","")))+1)
			roofs.item_selected.connect(func(index): document.set_property(ref,"roof_style","auto" if index==0 else roof_ids[index-1]))
			inspector.add_child(roofs)
			label(inspector,"关联门（多扇门用英文逗号分隔）",13)
			var doors := LineEdit.new()
			doors.name = "VisibilityDoors"
			doors.text = ",".join(item.get("door_ids",[]))
			doors.focus_exited.connect(func():
				if refreshing: return
				var values: Array = []
				for value in doors.text.split(",",false): values.append(value.strip_edges())
				document.set_property(ref,"door_ids",values))
			inspector.add_child(doors)
			label(inspector,"试跑时：主角进入揭顶，离开重盖；编辑视图完整显示。",13)
		if ref.group == "access_doors":
			label(inspector,"劳动门禁 · 08–12 / 14–18锁门" if item.get("kind","") == "workshop" else "定时门" if item.get("kind","") == "timed" else "禁闭门 · 捕获后锁定")
			if item.get("kind","") == "timed":
				for index in range(2):
					label(inspector,"开放 / 关闭分钟（12:00 = 720）" if index == 0 else "关闭分钟（14:00 = 840）",13)
					var spin := SpinBox.new()
					spin.name = "DoorMinute%d" % index
					spin.min_value = 0
					spin.max_value = 1440
					spin.value = item.get("hours",[720,840])[index]
					spin.value_changed.connect(func(value):
						if refreshing: return
						var hours: Array = item.get("hours",[720,840]).duplicate()
						hours[index] = value
						document.set_property(ref,"hours",hours))
					inspector.add_child(spin)
		if ref.group == "confinement":
			var roofed := CheckButton.new()
			roofed.name = "RoofedCell"
			roofed.add_theme_constant_override("icon_max_width",24)
			roofed.text = "完整封顶 · 遮住内部"
			roofed.icon = catalog.icon({"id":"solitary_roof_v23","icon":catalog.assets.get("solitary_roof_v23",{}).get("editor_icon","")})
			roofed.button_pressed = item.get("building",{}).get("roofed",false)
			roofed.toggled.connect(func(on):
				var building: Dictionary = item.get("building",{}).duplicate(true)
				building.roofed = on
				document.set_property(ref,"building",building))
			inspector.add_child(roofed)
			label(inspector,"建筑立面高度",13)
			var building_height := SpinBox.new()
			building_height.name = "BuildingHeight"
			building_height.min_value = 18
			building_height.max_value = minf(200,rect.size.y-24)
			building_height.value = item.get("building",{}).get("height",110)
			building_height.value_changed.connect(func(value):
				if refreshing: return
				var building: Dictionary = item.get("building",{}).duplicate(true)
				building.height = value
				document.set_property(ref,"building",building))
			inspector.add_child(building_height)
			label(inspector,"关联禁闭门："+str(item.get("door_id","")),13)
			label(inspector,"关押分钟（所有禁闭室）",13)
			var duration := SpinBox.new()
			duration.name = "ConfinementMinutes"
			duration.min_value = 1
			duration.max_value = 1440
			duration.value = document.data.confinement.get("duration_minutes",120)
			duration.value_changed.connect(func(value):
				if refreshing: return
				document.begin()
				document.data.confinement.duration_minutes = value
				document.commit())
			inspector.add_child(duration)
			for property in ["spawn","release"]:
				for axis in range(2):
					label(inspector,("关押点" if property == "spawn" else "释放点")+(" X" if axis == 0 else " Y"),13)
					var spin := SpinBox.new()
					spin.name = "Cell_"+property+str(axis)
					spin.min_value = -10000
					spin.max_value = 10000
					spin.value = item[property][axis]
					spin.value_changed.connect(func(value):
						if refreshing: return
						var point: Array = item[property].duplicate()
						point[axis] = value
						document.set_property(ref,property,point))
					inspector.add_child(spin)
		if ref.group == "fixtures":
			label(inspector,"摆设样式")
			var appearance := OptionButton.new()
			appearance.name = "FixtureAppearance"
			var choices: Array[String] = catalog.appearance_ids(str(item.asset_id))
			for asset in choices:
				var legacy := "（旧地图引用）" if not catalog.is_placeable(asset) else ""
				appearance.add_item(catalog.display_name(asset)+legacy)
			appearance.select(choices.find(str(item.asset_id)))
			appearance.item_selected.connect(func(index): document.set_property(ref,"asset_id",choices[index]); canvas.queue_redraw())
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
	commit_fields()
	if not can_edit_selection(): return
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
	if not layers.is_editable(group):
		show_status(Layers.NAMES[layers.key_for(group)]+"已隐藏或锁定，请先显示并解锁。")
		return
	var asset: String = str(placement.get("asset_id","")) if group == "fixtures" else str(placement.get("definition_id","scrap"))
	if group == "fixtures" and asset == "":
		show_status("请先在素材卡片中选择摆设。")
		return
	canvas.choose(document.add(group,point,asset))
	show_status("已添加 "+Document.GROUP_NAMES.get(group,group)+"；可继续放置，或选“选择/拖动”调整。")

func duplicate_selected() -> void:
	commit_fields()
	if can_edit_selection():
		canvas.choose(document.duplicate_entry(selection))

func delete_selected() -> void:
	commit_fields()
	if can_edit_selection() and document.can_remove(selection):
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
	elif event.keycode == KEY_V:
		set_tool("select")
	elif event.keycode == KEY_H:
		set_tool("pan")
	elif event.keycode == KEY_B:
		set_tool("walls")
	elif event.keycode == KEY_ESCAPE:
		canvas.finish_gesture(true)
		canvas.choose({})
		set_tool("select")
	else:
		return
	get_viewport().set_input_as_handled()
