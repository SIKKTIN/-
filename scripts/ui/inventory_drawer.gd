extends Node

const HudArt = preload("res://scripts/ui/hud_skin.gd")

class SlotFace extends Control:
	var drawer
	var index := 0
	func _draw():
		var bag: Array = drawer.game.inventory.items(0)
		var filled := index<bag.size()
		var kind: String = str(drawer.game.inventory.instances[bag[index]].definition_id) if filled else "empty"
		var icon: Texture2D = drawer.icon_for(kind)
		var room := Rect2(12,10,size.x-24,size.y-41)
		if icon:
			var fitted: Vector2 = icon.get_size()*minf(room.size.x/icon.get_width(),room.size.y/icon.get_height())
			draw_texture_rect(icon,Rect2(room.position+(room.size-fitted)/2,fitted),false,Color.WHITE if filled else Color(1,1,1,0.24))
		var text: String = str(drawer.game.inventory.definitions[kind].name) if filled else "空位"
		var width: float = drawer.ui.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(drawer.ui.font,Vector2((size.x-width)/2,size.y-12),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,HudArt.INK if filled else Color("979c90"))

var ui
var game
var paper: Panel
var header: Panel
var capacity: Label
var close_button: Button
var slot_faces: Array = []
var detail: Panel
var thumbnail: TextureRect
var item_name: Label
var item_type: Label
var description: Label
var hint: Label
var header_icon: TextureRect
var icons := {}
var display_key: Array = []
var layout_key: Array = []

func configure(owner_ui):
	ui = owner_ui
	game = ui.game
	_load_icons()
	paper = HudArt.Plate.new()
	paper.name = "CurrentInventory"
	paper.z_index = 105
	game.get_node("HUD").add_child(paper)
	header = HudArt.Plate.new()
	header.canvas_header = true
	paper.add_child(header)
	header_icon = TextureRect.new()
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_icon)
	var title := label(header,22)
	title.name = "Title"
	title.text = "随身背包"
	capacity = label(header,18)
	close_button = Button.new()
	close_button.name = "CloseBackpack"
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size",22)
	HudArt.button(close_button)
	for state in ["normal","hover","pressed","disabled"]:
		var compact_style: StyleBoxFlat = close_button.get_theme_stylebox(state).duplicate()
		compact_style.set_content_margin_all(4)
		close_button.add_theme_stylebox_override(state,compact_style)
	close_button.pressed.connect(func():
		ui.bag_open = false
		if game.shop_panel.panel.visible: game.shop_panel.close()
		ui.refresh())
	header.add_child(close_button)
	game.inventory_panel.label.hide()
	for index in range(game.inventory_panel.slots.size()):
		var slot: Button = game.inventory_panel.slots[index]
		slot.reparent(paper,false)
		slot.theme = ui.theme
		var face := SlotFace.new()
		face.drawer = self
		face.index = index
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		slot.add_child(face)
		slot_faces.append(face)
	detail = Panel.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_stylebox_override("panel",HudArt.box("inset"))
	paper.add_child(detail)
	thumbnail = TextureRect.new()
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	detail.add_child(thumbnail)
	item_name = label(detail,22)
	item_type = label(detail,13)
	item_type.add_theme_color_override("font_color",Color("727a6e"))
	description = label(detail,16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint = label(paper,13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color",Color("70796e"))
	for button in [game.inventory_panel.use_button,game.inventory_panel.drop_button]:
		button.reparent(paper,false)
		button.add_theme_font_size_override("font_size",20)
		HudArt.button(button,button==game.inventory_panel.use_button)
	game.inventory_panel.drop_button.text = "丢弃"
	game.inventory_panel.drop_button.icon = null
	for button in game.inventory_panel.transfer_buttons: button.hide()
	game.mini_map.stop_button.hide()
	paper.hide()

func label(parent: Control, size: int) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",ui.font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",HudArt.INK)
	parent.add_child(result)
	return result

func icon_for(kind: String) -> Texture2D:
	return icons.get(kind,game.items_view.icon_for(kind))

func _load_icons():
	var path := "res://art/ui/single_player_v01/inventory-icons.png"
	var texture: Texture2D = load(path)
	var pixels := texture.get_image()
	if pixels==null or pixels.is_empty(): return
	var cell := Vector2i(pixels.get_width()/2,pixels.get_height()/2)
	var kinds := ["door_key","lock_tool","scrap","backpack"]
	for i in range(4):
		var origin := Vector2i((i%2)*cell.x,(i/2)*cell.y)
		var bounds: Rect2i = pixels.get_region(Rect2i(origin,cell)).get_used_rect()
		var icon := AtlasTexture.new()
		icon.atlas = texture
		icon.region = Rect2(origin+bounds.position,bounds.size)
		icon.filter_clip = true
		icons[kinds[i]] = icon

func layout():
	var safe: Rect2 = ui.safe_area()
	var width := clampf(safe.size.x*0.35,360,440)
	var bottom: float = minf(minf(ui.bag_button.position.y,ui.ability_button.position.y),ui.action_button.position.y)-12
	var top: float = safe.position.y+(104 if safe.size.y<620 else 118)
	var height := minf(500,maxf(280,bottom-top))
	paper.size = Vector2(width,height)
	paper.position = Vector2(safe.end.x-width,bottom-height)
	header.position = Vector2(5,5)
	var compact := height<400
	header.size = Vector2(width-10,52 if compact else 64)
	header_icon.position = Vector2(13,10)
	header_icon.size = Vector2(40,44)
	if compact:
		header_icon.position.y = 6
		header_icon.size.y = 38
	header.get_node("Title").position = Vector2(62,12 if compact else 18)
	capacity.position = Vector2(width-137,16 if compact else 22)
	close_button.position = Vector2(width-65,11)
	close_button.size = Vector2(44,42)
	var capacity_count: int = game.inventory.capacity(0)
	var slot_height := 72.0 if compact else 122.0
	var slot_y := 58.0 if compact else 80.0
	var slot_width: float = minf(130,(width-48)/capacity_count)
	var row_width: float = capacity_count*slot_width+(capacity_count-1)*8
	for index in range(game.inventory_panel.slots.size()):
		var slot: Button = game.inventory_panel.slots[index]
		slot.position = Vector2((width-row_width)/2+index*(slot_width+8),slot_y)
		slot.size = Vector2(slot_width,slot_height)
		slot_faces[index].size = slot.size
	var detail_y := slot_y+slot_height+10
	detail.position = Vector2(16,detail_y)
	detail.size = Vector2(width-32,height-detail_y-(74 if compact else 104))
	var thumb_size := 26.0 if compact else 90.0
	thumbnail.position = Vector2(12,8 if compact else 12)
	thumbnail.size = Vector2(thumb_size,thumb_size)
	var text_left := thumb_size+24
	item_name.position = Vector2(text_left,12)
	item_name.size = Vector2(detail.size.x-text_left-12,30)
	item_type.position = Vector2(text_left,44)
	item_type.size = Vector2(detail.size.x-text_left-12,20)
	description.position = Vector2(text_left,68)
	description.size = Vector2(detail.size.x-text_left-12,detail.size.y-80)
	if compact:
		item_name.add_theme_font_size_override("font_size",18)
		item_name.position.y = 8
		description.add_theme_font_size_override("font_size",13)
		description.position = Vector2(12,38)
		description.size = Vector2(detail.size.x-24,maxf(0,detail.size.y-44))
	else:
		item_name.add_theme_font_size_override("font_size",22)
		description.add_theme_font_size_override("font_size",16)
	item_type.visible = not compact
	hint.visible = not compact
	var buttons := [game.inventory_panel.use_button,game.inventory_panel.drop_button]
	for i in range(buttons.size()):
		buttons[i].position = Vector2(16+i*(width-24)/2,height-(66 if compact else 90))
		buttons[i].size = Vector2((width-40)/2,42 if compact else 50)
	hint.position = Vector2(18,height-23 if compact else height-32)
	hint.size = Vector2(width-36,28)
	if game.shop_panel.panel.visible:
		var shop: Panel = game.shop_panel.panel
		shop.position = Vector2(safe.position.x+maxf(0,(paper.position.x-safe.position.x-shop.size.x-12)/2),safe.get_center().y-shop.size.y/2)

func refresh():
	var inv = game.inventory_panel
	var bag: Array = game.inventory.items(0)
	var count: int = game.inventory.capacity(0)
	var shop_open: bool = game.shop_panel.panel.visible
	var blocked: bool = game.world_input_blocked()
	for button in inv.transfer_buttons: button.hide()
	game.mini_map.stop_button.hide()
	paper.visible = (ui.bag_open or shop_open) and not ui.menu.visible and not game.schedule.panel.visible and not game.developer_settings.panel.visible and not game.dialogue.panel.visible and game.phase=="playing" and not (game.tutorial and game.tutorial.blocks_input())
	if not paper.visible: return
	var arrangement := [ui.last_size,ui.bag_button.position,ui.ability_button.position,ui.action_button.position,count,shop_open]
	if arrangement!=layout_key or inv.slots[0].size.x<60:
		layout()
		layout_key = arrangement.duplicate()
	capacity.text = "%d / %d" % [bag.size(),count]
	header_icon.texture = icon_for("backpack")
	if not game.inventory.owns(0,inv.selected_item) and not bag.is_empty(): inv.selected_item = str(bag[0])
	var selected: bool = game.inventory.owns(0,inv.selected_item)
	var key := [bag.duplicate(),inv.selected_item,count,blocked,shop_open]
	for index in range(inv.slots.size()):
		var slot: Button = inv.slots[index]
		slot.visible = index<count
		slot.disabled = blocked and not shop_open
		slot.text = ""
		slot.icon = null
		slot.modulate = Color.WHITE
		var chosen: bool = index<bag.size() and bag[index]==inv.selected_item
		if display_key!=key:
			slot.add_theme_stylebox_override("normal",HudArt.box("selected" if chosen else "inset"))
			slot.add_theme_stylebox_override("hover",HudArt.box("selected"))
			slot.add_theme_stylebox_override("pressed",HudArt.box("selected"))
			slot_faces[index].queue_redraw()
	var kind: String = str(game.inventory.instances[inv.selected_item].definition_id) if selected else ""
	var definition: Dictionary = game.inventory.definitions.get(kind,{})
	item_name.text = str(definition.get("name","背包是空的"))
	item_type.text = "一次性工具" if kind in ["door_key","lock_tool"] else "可携带物品" if selected else "每个格子携带一件物品"
	description.text = {"door_key":"靠近对应铁门使用，立即开锁。成功后消耗。","lock_tool":"靠近铁门使用，撬锁需要6秒。移动会中断。","scrap":"旧零件可以携带或带出，商人不收购。"}.get(kind,"靠近物品拾取，或向商人购买工具。")
	thumbnail.texture = icon_for(kind) if selected else icon_for("backpack")
	var use_reason: String = game.skills.door_reason(game.actors[0],55) if kind in ["door_key","lock_tool"] else "这件物品可携带，无法直接使用。" if selected else "选择物品查看用途。"
	inv.use_button.visible = true
	inv.drop_button.visible = true
	inv.use_button.disabled = not selected or blocked or not use_reason.is_empty() or game.skills.actions.has(0)
	inv.drop_button.disabled = not selected or blocked
	inv.use_button.tooltip_text = use_reason
	hint.text = "交易中 · 点击物品格查看详情" if shop_open else "靠近可互动目标时使用" if kind in ["door_key","lock_tool"] else "选择物品查看用途 · 每格一件物品"
	display_key = key
