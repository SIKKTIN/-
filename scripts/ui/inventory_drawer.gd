extends Node

const DragPreview=preload("res://scripts/ui/looting_drag_preview.gd")
const HudArt = preload("res://scripts/ui/hud_skin.gd")
const Art = preload("res://scripts/ui/looting_skin.gd")
const CardArt=preload("res://scripts/ui/keycard_art.gd")
const QuickSlot = preload("res://scripts/ui/quick_slot_button.gd")

class SlotFace extends Control:
	var drawer
	var index := 0
	func _draw():
		var bag: Array = drawer.game.inventory.items(0)
		var filled := index<bag.size()
		for x in range(4,int(size.x)-4,7):
			for y in [2.0,size.y-2]:draw_line(Vector2(x,y),Vector2(x+3,y),Color(0.31,0.30,0.25,0.43),1,true)
		for y in range(4,int(size.y)-4,7):
			for x in [2.0,size.x-2]:draw_line(Vector2(x,y),Vector2(x,y+3),Color(0.31,0.30,0.25,0.43),1,true)
		if not filled:
			var center:=size/2
			draw_line(center-Vector2(5,0),center+Vector2(5,0),Color("b4b2a0"),2,true)
			draw_line(center-Vector2(0,5),center+Vector2(0,5),Color("b4b2a0"),2,true)
			return
		var kind: String = str(drawer.game.inventory.instances[bag[index]].definition_id) if filled else "empty"
		var icon: Texture2D = drawer.icon_for(kind)
		var card: bool=drawer.game.keycards and drawer.game.keycards.is_card(str(bag[index]))
		var room := Rect2(6,5,size.x-12,size.y-(25 if card else 10))
		if icon:
			var fitted: Vector2 = icon.get_size()*minf(room.size.x/icon.get_width(),room.size.y/icon.get_height())
			var fitted_rect:=Rect2(room.position+(room.size-fitted)/2,fitted)
			draw_texture_rect(icon,fitted_rect,false,Color.WHITE if filled else Color(1,1,1,0.24))
			if card:
				drawer.CardArt.caption(self,drawer.game,str(bag[index]),drawer.ui.font,fitted_rect)
				draw_string(drawer.ui.font,Vector2(4,size.y-7),drawer.game.inventory.item_name(str(bag[index])),HORIZONTAL_ALIGNMENT_CENTER,size.x-8,clampi(int(size.x/8),9,13),Art.INK)


class DropGuide extends Control:
	var drawer
	var rect:=Rect2()
	var state:=0
	func _draw():
		if state==0:return
		var color:=Color("48c7a0") if state==1 else Color("de795f")
		draw_rect(rect,Color(color,0.24),true)
		draw_rect(rect,color,false,3)
	func _notification(what: int):
		if what==NOTIFICATION_DRAG_END and drawer!=null:drawer.finish_drag()

var ui
var game
var category := "all"
var category_buttons: Array=[]
var card_note: Label
var paper: Panel
var blocker: ColorRect
var bag_surface: Panel
var capacity_tag: Panel
var binding_footer: Panel
var binding_title: Label
var binding_buttons: Array = []
var slot_styles: Dictionary = {}
var header: Panel
var capacity: Label
var close_button: Button
var slot_faces: Array = []
var detail: Panel
var thumbnail: TextureRect
var item_name: Label
var item_type: Label
var permission_list: VBoxContainer
var permission_key: Array=[]
var description_column: VBoxContainer
var description_scroll: ScrollContainer
var description: Label
var hint: Label
var header_icon: TextureRect
var icons := {}
var display_key: Array = []
var layout_key: Array = []
var grid_scroll: ScrollContainer
var grid_holder: Control
var grid_cell:=56.0
var drop_guide
var drag_preview
var drag_payload: Dictionary={}
var drag_pointer:=Vector2.ZERO

func configure(owner_ui):
	ui = owner_ui
	game = ui.game
	_load_icons()
	blocker = ColorRect.new()
	blocker.name = "BackpackBlocker"
	blocker.color = Color(0.025,0.04,0.035,0.38)
	blocker.z_index = 104
	game.get_node("HUD").add_child(blocker)
	blocker.hide()
	paper = Panel.new()
	paper.add_theme_stylebox_override("panel",Art.box(Color("eee8d7"),Color("607568"),9,0))
	paper.name = "CurrentInventory"
	paper.z_index = 105
	game.get_node("HUD").add_child(paper)
	bag_surface = Panel.new()
	bag_surface.add_theme_stylebox_override("panel",Art.box(Color("eee8d7"),Color("c8c5b2"),5,0))
	paper.add_child(bag_surface)
	header = Art.SewnTag.new()
	bag_surface.add_child(header)
	header_icon = TextureRect.new()
	header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_icon)
	var title := label(header,22)
	title.name = "Title"
	title.text = "随身背包"
	capacity_tag = Art.SewnTag.new()
	bag_surface.add_child(capacity_tag)
	capacity = label(capacity_tag,18)
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_icon.hide()
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
	paper.add_child(close_button)
	grid_scroll=ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	grid_scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	bag_surface.add_child(grid_scroll)
	grid_holder=Control.new()
	grid_holder.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	grid_scroll.add_child(grid_holder)
	grid_holder.set_drag_forwarding(no_drag,can_drop_here.bind(grid_holder),drop_here.bind(grid_holder))
	grid_scroll.set_drag_forwarding(no_drag,can_drop_here.bind(grid_scroll),drop_here.bind(grid_scroll))
	slot_styles["empty"] = Art.box(Color("ddd8c5"),Color("c8c5b2"),5,0)
	slot_styles["selected"] = Art.box(Color("dedfc9"),Art.TEAL,5,0)
	slot_styles["selected"].set_border_width_all(2)
	for index in range(game.inventory_panel.slots.size()):
		var slot: Button = game.inventory_panel.slots[index]
		slot.reparent(grid_holder,false)
		slot.theme = ui.theme
		slot.set_drag_forwarding(make_drag.bind(index),can_drop_here.bind(slot),drop_here.bind(slot))
		var face := SlotFace.new()
		face.drawer = self
		face.index = index
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for state in ["normal","disabled"]:slot.add_theme_stylebox_override(state,slot_styles.empty)
		for state in ["hover","pressed"]:slot.add_theme_stylebox_override(state,slot_styles.selected)
		slot.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		slot.add_child(face)
		slot_faces.append(face)
	drop_guide=DropGuide.new()
	drop_guide.drawer=self
	drop_guide.mouse_filter=Control.MOUSE_FILTER_IGNORE
	drop_guide.z_index=1
	grid_holder.add_child(drop_guide)
	drag_preview=DragPreview.new()
	drag_preview.compact=true
	drag_preview.font=ui.font
	game.get_node("HUD").add_child(drag_preview)
	drag_preview.hide()
	detail = Panel.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_stylebox_override("panel",Art.box(Color("f1ead7"),Color("8d998b"),5,0))
	paper.add_child(detail)
	thumbnail = CardArt.CardThumbnail.new()
	thumbnail.game=game
	thumbnail.font=ui.font
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	detail.add_child(thumbnail)
	item_name = label(detail,22)
	item_name.add_theme_color_override("font_color",Art.INK)
	item_type = label(detail,13)
	item_type.add_theme_color_override("font_color",Color("687469"))
	description_scroll=ScrollContainer.new()
	description_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	description_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	detail.add_child(description_scroll)
	description_column=VBoxContainer.new()
	description_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	description_scroll.add_child(description_column)
	permission_list=VBoxContainer.new()
	permission_list.add_theme_constant_override("separation",4)
	description_column.add_child(permission_list)
	permission_list.hide()
	description = label(description_column,16)
	description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	description.add_theme_color_override("font_color",Art.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	binding_footer = Panel.new()
	binding_footer.add_theme_stylebox_override("panel",Art.box(Color("e4decb"),Color("b7b9a5"),5,0))
	paper.add_child(binding_footer)
	binding_title = label(binding_footer,18)
	binding_title.text = "快捷道具"
	binding_title.add_theme_color_override("font_color",Art.INK)
	hint = label(binding_footer,13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color",Color("687469"))
	for button in [game.inventory_panel.use_button,game.inventory_panel.drop_button]:
		button.reparent(detail,false)
		button.add_theme_font_size_override("font_size",20)
		button.add_theme_font_override("font",ui.font)
		Art.style_button(button,button==game.inventory_panel.use_button)
	game.inventory_panel.drop_button.text = "丢弃"
	game.inventory_panel.drop_button.icon = null
	for index in range(4):
		var button := QuickSlot.new()
		button.name = "BindQuick%d" % (index+1)
		button.index = index
		button.binding_mode = true
		button.font = ui.font
		button.pressed.connect(select_binding.bind(index))
		button.clear_requested.connect(clear_binding)
		button.set_drag_forwarding(no_drag,can_bind.bind(index),drop_binding.bind(index))
		binding_footer.add_child(button)
		binding_buttons.append(button)
	for key in ["all","tool","document"]:
		var tab:=Button.new()
		tab.name="Category_"+key
		tab.text={"all":"全部","tool":"工具","document":"证件"}[key]
		tab.focus_mode=Control.FOCUS_NONE
		tab.add_theme_font_override("font",ui.font)
		tab.add_theme_font_size_override("font_size",16)
		tab.pressed.connect(select_category.bind(key))
		bag_surface.add_child(tab)
		category_buttons.append(tab)
	card_note=label(detail,13)
	card_note.add_theme_color_override("font_color",Art.TEAL)
	card_note.text="✓ 自动匹配 · 刷卡不消耗"
	card_note.hide()
	paper.move_child(close_button,paper.get_child_count()-1)
	game.get_window().focus_exited.connect(cancel_drag)
	paper.hide()

func label(parent: Control, size: int) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font",ui.font)
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",HudArt.INK)
	parent.add_child(result)
	return result

func matches_category(id: String) -> bool:
	if category=="all": return true
	var kind: String=game.inventory.instances[id].definition_id
	var item_category: String=str(game.inventory.definitions[kind].get("category","misc"))
	return item_category=="document" if category=="document" else item_category in ["tool","equipment"]

func select_category(key: String):
	cancel_drag()
	category=key
	layout_key.clear()
	display_key.clear()
	var ids: Array=game.inventory.items(0).filter(matches_category)
	game.inventory_panel.selected_item=str(ids[0]) if not ids.is_empty() else ""
	refresh()

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
	var top: float = safe.position.y+112
	var shop_open: bool = game.shop_panel.panel.visible
	var width := minf(1000,safe.size.x)
	if shop_open:
		var shop: Panel = game.shop_panel.panel
		shop.size.x = minf(490,safe.size.x*0.48)
		shop.position = Vector2(safe.position.x,safe.get_center().y-shop.size.y/2)
		width = safe.size.x-shop.size.x-12
	paper.size = Vector2(width,minf(560,safe.end.y-top-8))
	paper.position = Vector2(safe.end.x-width if shop_open else safe.get_center().x-width/2,top)
	blocker.position = Vector2.ZERO
	blocker.size = game.get_viewport_rect().size
	var compact := paper.size.y < 440 or shop_open
	var card: bool=game.keycards and game.keycards.is_card(game.inventory_panel.selected_item)
	var body_height: float = paper.size.y-126
	var bag_width: float = floorf((width-42)*0.62)
	bag_surface.position = Vector2(14,14)
	bag_surface.size = Vector2(bag_width,body_height)
	header.position = Vector2(22,18)
	header.size = Vector2(174 if not shop_open else 108,43)
	header.get_node("Title").position = Vector2(16,8)
	header.get_node("Title").add_theme_font_size_override("font_size",20 if not shop_open else 16)
	capacity_tag.size = Vector2(112 if not shop_open else 85,43)
	capacity_tag.position = Vector2(bag_width-capacity_tag.size.x-22,18)
	capacity.position = Vector2(4,9)
	capacity.size = capacity_tag.size-Vector2(8,14)
	capacity.add_theme_font_size_override("font_size",17 if not shop_open else 13)
	close_button.position = Vector2(width-59,13)
	close_button.size = Vector2(42,42)
	var dimensions: Vector2i = game.inventory.grid_size(0)
	for i in category_buttons.size():
		var tab: Button=category_buttons[i]
		tab.position=Vector2(22+i*91,68)
		tab.size=Vector2(84,32)
		Art.style_button(tab,category==["all","tool","document"][i])
	grid_cell = floorf(minf((bag_width-52)/dimensions.x,(body_height-125)/4))
	grid_scroll.position = Vector2(floorf((bag_width-grid_cell*5)/2),112)
	grid_scroll.size = Vector2(grid_cell*5+12,grid_cell*4+1)
	grid_holder.custom_minimum_size = Vector2(dimensions)*grid_cell
	if category!="all":
		grid_cell=floorf(minf((bag_width-52)/4,(body_height-125)/2))
		var filtered_count: int=game.inventory.items(0).filter(matches_category).size()
		grid_scroll.position.x=floorf((bag_width-grid_cell*4)/2)
		grid_scroll.size=Vector2(grid_cell*4+12,body_height-125)
		grid_holder.custom_minimum_size=Vector2(4,maxi(2,ceili(filtered_count/4.0)))*grid_cell
	drop_guide.size = grid_holder.custom_minimum_size
	var arrangement: Dictionary = game.inventory.grid_layout(0)
	var rectangles: Array = []
	var visible_index:=0
	for id in game.inventory.items(0):
		if category=="all": rectangles.append(arrangement[id])
		elif matches_category(str(id)):
			rectangles.append(Rect2i(visible_index%4,visible_index/4,1,1))
			visible_index+=1
		else: rectangles.append(Rect2i(-1,-1,1,1))
	if category=="all":
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				if not arrangement.values().any(func(rect): return rect.has_point(Vector2i(x,y))): rectangles.append(Rect2i(x,y,1,1))
	else:
		for index in range(visible_index,maxi(8,ceili(visible_index/4.0)*4)): rectangles.append(Rect2i(index%4,index/4,1,1))
	for index in range(game.inventory_panel.slots.size()):
		var slot: Button = game.inventory_panel.slots[index]
		slot.visible = index < rectangles.size() and rectangles[index].position.x>=0
		if not slot.visible: continue
		var rect: Rect2i = rectangles[index]
		slot.position = Vector2(rect.position)*grid_cell+Vector2(2,2)
		slot.size = Vector2(rect.size)*grid_cell-Vector2(4,4)
		slot_faces[index].size = slot.size
	detail.position = Vector2(bag_width+26,14)
	detail.size = Vector2(width-bag_width-40,body_height)
	var padding := 12.0 if compact else 20.0
	item_name.position = Vector2(padding,18)
	item_name.size = Vector2(detail.size.x-padding*2-40,30)
	item_name.add_theme_font_size_override("font_size",18 if compact else 23)
	item_type.position = Vector2(padding,46 if compact else 52)
	item_type.size = Vector2(detail.size.x-padding*2,23)
	var thumb_height := 44.0 if compact else minf(112,body_height*0.26)
	thumbnail.position = Vector2(padding,70 if compact else 80)
	thumbnail.size = Vector2(detail.size.x-padding*2,thumb_height)
	description_scroll.position = Vector2(padding,thumbnail.position.y+thumb_height+12)
	if compact and card:
		thumbnail.position=Vector2(detail.size.x-padding-minf(88,detail.size.x*0.3)-48,18)
		thumbnail.size=Vector2(minf(88,detail.size.x*0.3),44)
		item_name.size.x=maxf(70,detail.size.x-padding*2-thumbnail.size.x-8)
		description_scroll.position.y=66
	item_type.visible=not (compact and card)
	description_scroll.size = Vector2(detail.size.x-padding*2,maxf(28,body_height-(84 if compact and card else 96 if card else 90 if compact else 108)-description_scroll.position.y))
	description.position=Vector2.ZERO
	description.custom_minimum_size=Vector2(description_scroll.size.x-12,0)
	description.add_theme_font_size_override("font_size",13 if compact else 15)
	description_scroll.visible = not (shop_open and width<600)
	for i in range(2):
		var button: Button = [game.inventory_panel.use_button,game.inventory_panel.drop_button][i]
		button.position = Vector2(padding,body_height-(84 if compact else 96)+i*(44 if compact else 46))
		button.size = Vector2(detail.size.x-padding*2,34 if compact and i==1 else 40)
		button.add_theme_font_size_override("font_size",16 if compact else 18)
	card_note.position=Vector2(padding,body_height-(76 if compact else 89))
	card_note.size=Vector2(detail.size.x-padding*2,25)
	binding_footer.position = Vector2(14,paper.size.y-104)
	binding_footer.size = Vector2(width-28,90)
	binding_title.position = Vector2(16,8)
	binding_title.size = Vector2(108,25)
	hint.position = Vector2(130,9)
	hint.size = Vector2(binding_footer.size.x-146,23)
	var slot_edge := 50.0 if compact else 56.0
	var slots_width := slot_edge*4+30
	for i in range(4):
		binding_buttons[i].size = Vector2.ONE*slot_edge
		binding_buttons[i].position = Vector2((binding_footer.size.x-slots_width)/2+i*(slot_edge+10),32)

func refresh():
	var inv = game.inventory_panel
	var bag: Array = game.inventory.items(0)
	var shop_open: bool = game.shop_panel.panel.visible
	var blocked: bool = game.world_input_blocked(true)
	paper.visible = (ui.bag_open or shop_open) and not ui.menu.visible and not game.schedule.panel.visible and not game.developer_settings.panel.visible and not game.dialogue.panel.visible and game.phase=="playing" and not (game.tutorial and game.tutorial.blocks_input()) and not (game.looting and game.looting.is_open()) and not (game.map_viewer and game.map_viewer.is_open())
	blocker.visible = paper.visible and not shop_open
	if not paper.visible:
		if not drag_payload.is_empty(): cancel_drag()
		return
	game.inventory.grid_layout(0)
	var arrangement: Array = [ui.last_size,game.inventory.capacity(0),shop_open,bag,game.inventory.layout_revision,game.inventory.metadata_revision,category,inv.selected_item]
	if arrangement != layout_key:
		layout()
		layout_key = arrangement.duplicate(true)
	capacity.text = "%d / %d格" % [game.inventory.used_cells(0),game.inventory.capacity(0)]
	var filtered: Array=bag.filter(matches_category)
	if not filtered.has(inv.selected_item): inv.selected_item = str(filtered[0]) if not filtered.is_empty() else ""
	var selected: bool = game.inventory.owns(0,inv.selected_item)
	var key: Array = [bag,inv.selected_item,blocked,shop_open,game.inventory.layout_revision]
	for index in range(inv.slots.size()):
		var slot: Button = inv.slots[index]
		slot.disabled = blocked and not shop_open
		slot.text = ""
		slot.icon = null
		if display_key == key: continue
		var chosen: bool = index<bag.size() and bag[index]==inv.selected_item
		slot.tooltip_text = game.inventory.item_name(str(bag[index])) if index<bag.size() else "空格"
		slot.add_theme_stylebox_override("normal",slot_styles.selected if chosen else slot_styles.empty)
		slot_faces[index].queue_redraw()
	var kind: String = game.inventory.instances[inv.selected_item].definition_id if selected else ""
	var definition: Dictionary = game.inventory.definitions.get(kind,{})
	item_name.text = game.inventory.item_name(inv.selected_item) if selected else "没有这类物品" if not bag.is_empty() else "背包是空的"
	item_type.text = str(preload("res://scripts/items/item_catalog.gd").CATEGORY_NAMES.get(definition.get("category","misc"),"其他")) if selected else "翻找柜子寻找物资"
	if selected:
		if definition.get("keycard",false): item_type.text="岗位："+str(definition.get("card_role","通行"))
		var shape: Vector2i = game.inventory.item_size(kind)
		item_type.text += " · 占用%d格" % (shape.x*shape.y)
	description.text = game.inventory.item_description(inv.selected_item) if selected else "点击物品查看用途；拖动自由整理背包。"
	thumbnail.texture = icon_for(kind) if selected else icon_for("backpack")
	thumbnail.item_id=inv.selected_item
	thumbnail.queue_redraw()
	var card: bool=selected and definition.get("keycard",false)
	permission_list.visible=card
	description.visible=not card
	if card: refresh_permissions(inv.selected_item)
	inv.use_button.visible=not card
	card_note.visible=card
	var use_reason: String = game.inventory.use_reason(0,inv.selected_item) if selected else "选择物品查看用途。"
	inv.use_button.text = game.inventory.action_label(inv.selected_item)
	inv.use_button.disabled = not selected or not use_reason.is_empty()
	inv.drop_button.disabled = not selected or blocked
	inv.use_button.tooltip_text = use_reason
	hint.text = "随身携带，靠近门时自动匹配" if category=="document" else "切回全部可整理背包" if category!="all" else "拖入绑定，物品仍留在背包"
	for i in range(4):
		var state: Dictionary = game.quick_items.state(i)
		binding_buttons[i].update_state(state,icon_for(str(state.kind)),blocked)
	display_key = key.duplicate(true)

func refresh_permissions(id: String):
	var rights: Array=game.keycards.permissions(id)
	var key: Array=[id,rights]
	if key==permission_key: return
	permission_key=key.duplicate(true)
	for child in permission_list.get_children(): child.free()
	var title:=label(permission_list,15)
	title.text="可开启的房间"
	for room_id in rights:
		var row:=PanelContainer.new()
		row.custom_minimum_size=Vector2(0,25)
		row.add_theme_stylebox_override("panel",Art.box(Color("ded9c6"),Color("c5c6b2"),4,2))
		permission_list.add_child(row)
		var text:=label(row,14)
		text.text="▸ "+str(game.keycards.room_by_id.get(str(room_id),{}).get("name",room_id))

func select_binding(index: int):
	var id: String = game.quick_items.first_item(game.quick_items.bindings[index])
	if not id.is_empty(): game.inventory_panel.selected_item = id
	refresh()

func clear_binding(index: int):
	game.quick_items.clear_slot(index)
	refresh()

func owned_drag(data) -> bool:
	return data is Dictionary and data.get("kind","")=="bag_layout" and data.get("controller",-1)==get_instance_id() and data==drag_payload and paper.visible

func binding_error(data, index: int) -> String:
	if not owned_drag(data): return "这次拖动已结束。"
	if game.world_input_blocked(true): return "当前无法绑定。"
	return game.quick_items.bind_reason(index,str(data.id))

func can_bind(_local: Vector2, data, index: int) -> bool:
	var error := binding_error(data,index)
	if owned_drag(data):
		binding_buttons[index].preview_drop(1 if error.is_empty() else -1)
		drop_guide.state = 0
		drop_guide.queue_redraw()
		drag_preview.feedback(1 if error.is_empty() else -1,"松手绑定" if error.is_empty() else error)
	return error.is_empty()

func drop_binding(local: Vector2, data, index: int):
	if not can_bind(local,data,index): return
	var result: Dictionary = game.quick_items.bind_item(index,str(data.id))
	game.show_status(str(result.reason))
	refresh()

func no_drag(_local: Vector2):
	return null

func make_drag(local: Vector2, index: int):
	var ids: Array=game.inventory.items(0)
	if category!="all": return null
	if not paper.visible or index<0 or index>=ids.size() or not game.inventory.owns(0,str(ids[index])):return null
	var id: String=str(ids[index])
	var rect: Rect2i=game.inventory.grid_layout(0)[id]
	var slot: Button=game.inventory_panel.slots[index]
	var grab:=Vector2i(((slot.position+local)/grid_cell).floor())-rect.position
	drag_payload={"kind":"bag_layout","controller":get_instance_id(),"id":id,"grab":grab}
	var kind: String=game.inventory.instances[id].definition_id
	drag_preview.icon=icon_for(kind)
	drag_preview.item_name=game.inventory.item_name(id)
	drag_preview.feedback(0,"整理 / 绑定")
	drag_preview.show()
	game.inventory_panel.selected_item=id
	return drag_payload

func target_cell(global_point: Vector2, data: Dictionary) -> Vector2i:
	return Vector2i(((global_point-grid_holder.global_position)/grid_cell).floor())-Vector2i(data.grab)

func placement_error(global_point: Vector2, data) -> String:
	if not data is Dictionary or data.get("kind","")!="bag_layout" or data.get("controller",-1)!=get_instance_id():return "无效的移动。"
	if not paper.visible or data!=drag_payload:return "背包已关闭。"
	if not grid_scroll.get_global_rect().has_point(global_point):return "请拖到背包格子中。"
	return game.inventory.placement_reason(0,str(data.id),target_cell(global_point,data),true)

func can_drop_here(_local: Vector2, data, _target: Control) -> bool:
	var point:=drag_pointer
	var error:=placement_error(point,data)
	if data is Dictionary and data.get("controller",-1)==get_instance_id():
		var state:=1 if error.is_empty() else -1
		var cell_point:=target_cell(point,data)
		var shape: Vector2i=game.inventory.item_size(str(game.inventory.instances.get(str(data.id),{}).get("definition_id","")))
		drop_guide.rect=Rect2(Vector2(cell_point)*grid_cell+Vector2(2,2),Vector2(shape)*grid_cell-Vector2(4,4))
		drop_guide.state=state
		drop_guide.queue_redraw()
		drag_preview.feedback(state,"松手放在此处" if error.is_empty() else "此处无法放置")
	return error.is_empty()

func drop_here(local: Vector2, data, target: Control):
	if not can_drop_here(local,data,target):return
	game.inventory.move_item(0,str(data.id),target_cell(drag_pointer,data))
	refresh()

func _input(event: InputEvent):
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventScreenTouch:
		drag_pointer=event.position
		if drag_payload.is_empty():return
		var viewport_size: Vector2=game.get_viewport_rect().size
		drag_preview.global_position=(drag_pointer+Vector2(18,16)).clamp(Vector2(6,6),viewport_size-drag_preview.size-Vector2(6,6))
		for button in binding_buttons:button.preview_drop(0)
		for index in range(4):
			if binding_buttons[index].get_global_rect().has_point(drag_pointer):
				can_bind(Vector2.ZERO,drag_payload,index)
				return
		if grid_scroll.get_global_rect().has_point(drag_pointer):can_drop_here(drag_pointer-grid_holder.global_position,drag_payload,grid_holder)
		else:
			drop_guide.state=0
			drop_guide.queue_redraw()
			drag_preview.feedback(0,"拖到空闲格子")

func cancel_drag():
	if paper and not drag_payload.is_empty():
		var viewport := paper.get_viewport()
		if viewport.gui_is_dragging() and viewport.gui_get_drag_data()==drag_payload:viewport.gui_cancel_drag()
	finish_drag()

func finish_drag():
	drag_payload={}
	if drag_preview:drag_preview.hide()
	if drop_guide:drop_guide.state=0;drop_guide.queue_redraw()
	for button in binding_buttons:button.preview_drop(0)
