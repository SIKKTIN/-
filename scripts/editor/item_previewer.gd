@tool
extends Control

const Catalog := preload("res://scripts/items/item_catalog.gd")
var catalog = Catalog.new()
var item_id := ""
var visible_ids: Array[String] = []
var item_list: ItemList
var search: LineEdit
var category_picker: OptionButton
var count_label: Label
var heading: Label
var details: RichTextLabel
var config_text: TextEdit
var stage
var category_ids: Array[String] = ["all"]

func make_label(parent: Node, text: String, pixels := 15) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size",pixels)
	parent.add_child(control)
	return control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://art/ui/fullscreen/theme.tres")
	build_ui()
	filter_items()
	if not visible_ids.is_empty(): select_item(visible_ids[0])
	if get_parent() == get_tree().root and not Engine.is_editor_hint(): get_window().title = "监狱风云 · 物品预览工具"

func build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",14)
	margin.add_theme_constant_override("margin_right",14)
	margin.add_theme_constant_override("margin_top",12)
	margin.add_theme_constant_override("margin_bottom",12)
	panel.add_child(margin)
	var root_box := VBoxContainer.new()
	margin.add_child(root_box)
	var toolbar := HBoxContainer.new()
	root_box.add_child(toolbar)
	make_label(toolbar,"物品预览工具",23).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reload_button := Button.new()
	reload_button.text = "重读物品库"
	reload_button.pressed.connect(reload_catalog)
	toolbar.add_child(reload_button)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 245
	split.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "搜索名称、ID、描述"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text): filter_items())
	left.add_child(search)
	category_picker = OptionButton.new()
	category_picker.add_item("全部物品")
	for id in Catalog.CATEGORY_NAMES:
		category_ids.append(id)
		category_picker.add_item(Catalog.CATEGORY_NAMES[id])
	category_picker.item_selected.connect(func(_index): filter_items())
	left.add_child(category_picker)
	count_label = make_label(left,"")
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.fixed_icon_size = Vector2i(44,44)
	item_list.item_selected.connect(func(index): select_item(visible_ids[index]))
	left.add_child(item_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	heading = make_label(right,"",22)
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(body)
	stage = preload("res://scripts/editor/item_preview_canvas.gd").new()
	stage.custom_minimum_size = Vector2(390,450)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 310
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(tabs)
	details = RichTextLabel.new()
	details.name = "物品情况"
	details.add_theme_font_size_override("normal_font_size",15)
	tabs.add_child(details)
	config_text = TextEdit.new()
	config_text.name = "原始配置"
	config_text.editable = false
	config_text.add_theme_font_size_override("font_size",13)
	tabs.add_child(config_text)
	var controls := HBoxContainer.new()
	right.add_child(controls)
	make_label(controls,"预览背景")
	var picker := OptionButton.new()
	for text in ["浅色棋盘","深色背景","地面色"]: picker.add_item(text)
	picker.item_selected.connect(func(index): stage.background = index; stage.queue_redraw())
	controls.add_child(picker)
	var copy_button := Button.new()
	copy_button.text = "复制物品ID"
	copy_button.pressed.connect(func(): DisplayServer.clipboard_set(item_id))
	controls.add_child(copy_button)
	make_label(root_box,"读取游戏实际物品库、图标和掉落配置；预览操作不会修改地图或背包。",13)

func reload_catalog() -> void:
	catalog.reload()
	filter_items()
	if catalog.definitions.has(item_id): select_item(item_id)

func filter_items() -> void:
	var query := search.text.strip_edges().to_lower()
	var category: String = category_ids[category_picker.selected]
	visible_ids.clear()
	item_list.clear()
	for id in catalog.definitions:
		var spec: Dictionary = catalog.definitions[id]
		if category != "all" and catalog.category(id) != category: continue
		if not query.is_empty() and not (id+str(spec.name)+str(spec.description)).to_lower().contains(query): continue
		visible_ids.append(id)
		item_list.add_item(str(spec.name),catalog.icon(id))
	count_label.text = "显示 %d / %d 种物品" % [visible_ids.size(),catalog.definitions.size()]
	if item_id in visible_ids: item_list.select(visible_ids.find(item_id))
	elif not visible_ids.is_empty(): select_item(visible_ids[0])
	else:
		item_id = ""
		heading.text = "没有匹配的物品"
		details.text = "试试其他关键词或分类。"
		config_text.text = ""
		stage.set_item(null,Vector2i.ONE)

func select_item(id: String) -> void:
	if not catalog.definitions.has(id): return
	item_id = id
	var spec: Dictionary = catalog.definitions[id]
	var size_values: Array = spec.get("grid_size",[1,1])
	var footprint := Vector2i(size_values[0],size_values[1])
	heading.text = str(spec.name)+"  ·  "+id
	stage.set_item(catalog.icon(id),footprint)
	var sources := catalog.sources(id)
	var art: Dictionary = catalog.art.get(id,{})
	var icon: Texture2D = catalog.icon(id)
	details.text = "分类：%s\n占格：%d × %d（%d 格）\n\n%s\n\n接入状态：%s\n操作：%s\n消耗物品：%s\n购买价格：%d\n\n搜刮来源：%s\n\n图标：%s\n素材路径：%s" % [Catalog.CATEGORY_NAMES.get(catalog.category(id),"其他"),footprint.x,footprint.y,footprint.x*footprint.y,str(spec.description),catalog.status(id),str(spec.get("use_action","收集 / 携带")),"是" if spec.get("consumable",false) else "否",int(spec.get("sell_price",0)),"、".join(sources) if not sources.is_empty() else "地图放置 / 商人配置",str(icon.get_size()) if icon != null else "缺失",str(art.get("texture","未配置"))]
	config_text.text = JSON.stringify({"item":spec,"art":art,"loot_sources":sources},"  ")
	if id in visible_ids: item_list.select(visible_ids.find(id))
