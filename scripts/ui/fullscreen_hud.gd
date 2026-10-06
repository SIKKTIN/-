extends Node

class ClockFace extends Button:
	var ui
	func _draw() -> void:
		if not ui or not ui.game.schedule:
			return
		var schedule = ui.game.schedule
		var minute: float = schedule.clock_minutes()
		var ink := Color("303b46")
		var alarm: bool = ui.game.prison_alert != null and ui.game.prison_alert.active
		var danger: bool = alarm or schedule.is_curfew() or schedule.real_remaining() <= 30
		var accent := Color("bc5348") if danger else ink
		draw_circle(Vector2(32,28),14,ink,false,2,true)
		draw_line(Vector2(32,28),Vector2(32,18),ink,2,true)
		draw_line(Vector2(32,28),Vector2(40,33),ink,2,true)
		var stage: String = schedule.config.stages[schedule.stage_index].name
		if alarm:
			stage = "全员警戒"
		draw_string(ui.font,Vector2(58,36),"%02d:%02d" % [floori(minute/60),floori(minute)%60],HORIZONTAL_ALIGNMENT_LEFT,-1,25,accent)
		draw_string(ui.font,Vector2(154,34),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,18,accent)
		var start := Vector2(24,54)
		var length: float = size.x-48
		var fraction := minute/1440.0
		draw_line(start,start+Vector2(length,0),Color("a6ac9a"),4,true)
		draw_line(start,start+Vector2(length*fraction,0),Color("c69c5e"),4,true)
		for hour in [0,8,12,18,20,24]:
			var point := start+Vector2(length*hour/24.0,0)
			draw_circle(point,3,Color("68776e"),true,-1,true)
			draw_string(ui.font,point+Vector2(-9,21),"%02d" % hour,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
		draw_circle(start+Vector2(length*fraction,0),6,Color("f2ebdd"),true,-1,true)
		draw_circle(start+Vector2(length*fraction,0),6,Color("c69c5e"),false,2,true)
		draw_string(ui.font,Vector2(24,92),"第%d天 · %s" % [schedule.day_number(),schedule.time_left_text()],HORIZONTAL_ALIGNMENT_LEFT,-1,14,accent)

class PartnerFace extends Control:
	var ui
	var index: int
	func _draw() -> void:
		var actor = ui.game.actors[index]
		var portrait: Texture2D = ui.portraits[index]
		if portrait:
			var area := Rect2(8,6,38,48)
			var fitted := portrait.get_size()*minf(area.size.x/portrait.get_width(),area.size.y/portrait.get_height())
			draw_texture_rect(portrait,Rect2(area.position+(area.size-fitted)/2,fitted),false)
		var ink := Color("303b46")
		draw_string(ui.font,Vector2(53,22),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
		var icon: Texture2D = ui.game.presentation.skill_icons.get(actor.skill_id)
		if actor.skill_id == "backpack":
			icon = ui.game.items_view.icon_for("backpack")
		if icon:
			draw_texture_rect(icon,Rect2(size.x-26,29,16,16),false)
		draw_string(ui.font,Vector2(53,39),ui.game.SKILL_NAMES[actor.skill_id],HORIZONTAL_ALIGNMENT_LEFT,size.x-82,13,ink)
		var state: String = "已逃脱" if actor.escaped else "移动中" if ui.game.orders.active.has(index) else {"idle":"待命","chatting":"交谈中","lockpicking":"撬锁中"}.get(actor.action_state,"待命")
		if ui.game.routines and ui.game.routines.status_for(index) != "" and not actor.escaped:
			state = ui.game.routines.status_for(index)
		if ui.game.schedule.is_curfew() and not actor.escaped:
			state = ui.game.schedule.actor_status(index)
		if actor.selected and not actor.escaped and ui.game.mobile_controls.is_moving():
			state = "移动中"
		draw_string(ui.font,Vector2(53,56),state,HORIZONTAL_ALIGNMENT_LEFT,size.x-61,13,Color("536052"))
		if ui.game.attributes:
			var values: Dictionary = ui.game.attributes.values[index]
			for row in range(2):
				var value: float = values.stamina if row == 0 else values.fullness
				var y: float = 63+row*12
				var tint := Color("c9534b") if value < 25 else Color("328b82") if row == 0 else Color("c69c5e")
				draw_string(ui.font,Vector2(8,y+4),"体力" if row == 0 else "饱腹",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("536052"))
				draw_rect(Rect2(38,y-3,size.x-78,5),Color("d3d7c8"))
				draw_rect(Rect2(38,y-3,(size.x-78)*clampf(value/100.0,0,1),5),tint)
				draw_string(ui.font,Vector2(size.x-34,y+4),str(roundi(value)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("536052"))
		elif ui.game.routines and ui.game.routines.is_working(index):
			draw_rect(Rect2(8,72,size.x-16,3),Color("d3d7c8"))
			draw_rect(Rect2(8,72,(size.x-16)*ui.game.routines.work_progress(index),3),Color("c69c5e"))
		if actor.selected and not actor.escaped:
			draw_circle(Vector2(size.x-17,14),9,Color("328b82"),true,-1,true)
			draw_line(Vector2(size.x-21,14),Vector2(size.x-17,18),Color.WHITE,2,true)
			draw_line(Vector2(size.x-17,18),Vector2(size.x-11,10),Color.WHITE,2,true)

class MobileButton extends Button:
	var ui
	var display_icon: Texture2D
	var primary := false
	func _draw() -> void:
		var ink := Color("303b46") if not disabled else Color("788176")
		var icon_size := 30.0 if primary else 18.0
		if display_icon:
			draw_texture_rect(display_icon,Rect2((size.x-icon_size)/2,18 if primary else 6,icon_size,icon_size),false,Color(1,1,1,0.45) if disabled else Color.WHITE)
		var font_size := 17 if primary else 14
		var lines := text.split("\n")
		for row in range(lines.size()):
			var text_width: float = ui.font.get_string_size(lines[row],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var baseline := size.y-10-(lines.size()-1-row)*16
			draw_string(ui.font,Vector2((size.x-text_width)/2,baseline),lines[row],HORIZONTAL_ALIGNMENT_LEFT,size.x-12,font_size,ink)

var game
var font: Font
var theme: Theme
var clock: ClockFace
var goal: Button
var wallet: Button
var routine_button: Button
var sleep_button: Button
var menu_button: Button
var menu: Panel
var menu_blocker: ColorRect
var inventory_paper: Panel
var toast: Panel
var faces: Array = []
var portraits: Array = []
var minimap_collapsed := false
var map_toggle: Button
var map_collapse: Button
var last_size := Vector2.ZERO
var action_button: MobileButton
var ability_button: MobileButton
var bag_button: MobileButton
var target_button: Button
var bag_open := false
var button_layout

func configure(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = game.presentation.font
	theme = load("res://art/ui/fullscreen/theme.tres") if ResourceLoader.exists("res://art/ui/fullscreen/theme.tres") else game.cards[0].theme
	var hud: Node = game.get_node("HUD")
	# Remove the old page furniture. Gameplay nodes and their callbacks stay.
	for control in hud.get_children():
		if control is Control:
			control.theme = theme
			if control is Label or control.name == "UseSkill":
				control.hide()
	game.presentation.lighting.toggle_button.hide()
	clock = ClockFace.new()
	clock.ui = self
	clock.theme = theme
	clock.focus_mode = Control.FOCUS_NONE
	clock.pressed.connect(func(): game.schedule.toggle())
	hud.add_child(clock)
	routine_button = _button("日常表",func(): game.routine_panel.toggle())
	routine_button.tooltip_text = "安排三位伙伴今天的工作、休息和活动。"
	sleep_button = _button("跳过夜晚",func(): game.schedule.skip_night())
	sleep_button.tooltip_text = "伙伴回各自床位并停止行动后，跳至次日08:00。"
	goal = _button("逃脱 0/3",Callable())
	goal.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet = _button("0",Callable(),"coin")
	menu_button = _button("",toggle_menu,"pause")
	menu_button.z_index = 240
	menu_button.tooltip_text = "暂停 / 菜单"
	for index in range(3):
		var portrait: Texture2D = load("res://art/ui/fullscreen/portrait_%d.tres" % (index+1)) if ResourceLoader.exists("res://art/ui/fullscreen/portrait_%d.tres" % (index+1)) else null
		portraits.append(portrait)
		var card: Button = game.cards[index]
		card.text = ""
		card.icon = null
		card.theme_type_variation = "PartnerCard"
		card.set_meta("base_style",theme.get_stylebox("normal","PartnerCard"))
		card.set_meta("selected_style",theme.get_stylebox("normal","SelectedPartnerCard"))
		card.focus_mode = Control.FOCUS_NONE
		var face := PartnerFace.new()
		face.ui = self
		face.index = index
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
		faces.append(face)
	inventory_paper = _paper("CurrentInventory")
	inventory_paper.z_index = 105 # Above shop, below schedule/developer/result.
	game.inventory_panel.label.reparent(inventory_paper,false)
	game.inventory_panel.label.show()
	for node in game.inventory_panel.slots+[game.inventory_panel.use_button,game.inventory_panel.drop_button]+game.inventory_panel.transfer_buttons:
		node.reparent(inventory_paper,false)
		node.theme = theme
	game.mini_map.stop_button.reparent(inventory_paper,false)
	game.mini_map.stop_button.icon = null
	game.mini_map.stop_button.text = "停止"
	action_button = _mobile_button("互动",func(): game.presentation.interaction.activate_mobile(),true)
	action_button.name = "MobileInteraction"
	ability_button = _mobile_button("技能",game.use_selected_skill)
	ability_button.name = "MobileAbility"
	bag_button = _mobile_button("背包",toggle_bag)
	bag_button.name = "MobileBag"
	bag_button.display_icon = game.items_view.icon_for("backpack")
	target_button = _button("切换",func(): game.presentation.interaction.cycle_mobile_target())
	target_button.name = "MobileTargetCycle"
	target_button.add_theme_font_size_override("font_size",14)
	target_button.tooltip_text = "切换附近的互动目标"
	map_toggle = _button("地图",func(): minimap_collapsed = false; layout(),"locate")
	map_collapse = Button.new()
	map_collapse.text = "收起"
	map_collapse.theme = theme
	map_collapse.pressed.connect(func(): minimap_collapsed = true; layout())
	game.mini_map.add_child(map_collapse)
	toast = _paper("TransientNotice")
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.status_label.reparent(toast,false)
	game.status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.status_label.add_theme_font_size_override("font_size",14)
	menu_blocker = game.schedule._blocker("PauseBlocker",Rect2(),230)
	menu_blocker.process_mode = Node.PROCESS_MODE_ALWAYS
	menu = game.schedule._paper_panel("PauseMenu",Vector2.ZERO,Vector2(360,460),231)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	game.schedule._label(menu,Vector2(24,20),"这次怎么逃 · 已暂停",22)
	var resume: Button = game.schedule._button(menu,Vector2(24,66),"继续行动",close_menu)
	resume.size = Vector2(312,48)
	game.room_selector.reparent(menu,false)
	game.room_selector.z_index = 0
	game.room_selector.position = Vector2(24,122)
	game.room_selector.size = Vector2(312,48)
	game.presentation.mute_button.reparent(menu,false)
	game.presentation.mute_button.position = Vector2(24,180)
	game.presentation.mute_button.size = Vector2(148,48)
	var daily: Button = game.schedule._button(menu,Vector2(184,180),"查看日程",func(): close_menu(); game.schedule.toggle())
	daily.size = Vector2(152,48)
	var restart: Button = game.get_node("HUD/ResetRound")
	restart.reparent(menu,false)
	restart.text = "重新开始"
	restart.position = Vector2(24,238)
	restart.size = Vector2(312,48)
	game.developer_settings.button.reparent(menu,false)
	game.developer_settings.button.position = Vector2(24,296)
	game.developer_settings.button.size = Vector2(312,48)
	game.developer_settings.button.pressed.disconnect(game.developer_settings.toggle)
	game.developer_settings.button.pressed.connect(func(): close_menu(); game.developer_settings.toggle())
	var layout_button: Button = game.schedule._button(menu,Vector2(24,352),"按键布局",func(): button_layout.open())
	layout_button.name = "EditButtonLayout"
	layout_button.size = Vector2(312,48)
	game.schedule._label(menu,Vector2(24,416),"左侧摇杆移动 · 切换伙伴 · 右侧互动",14)
	menu.hide()
	menu_blocker.hide()
	# GUI hit order follows tree order. Shop can still select the floating bag.
	hud.move_child(inventory_paper,game.shop_panel.panel.get_index()+1)
	hud.move_child(menu_button,hud.get_child_count()-1)
	button_layout = load("res://scripts/ui/button_layout.gd").new()
	add_child(button_layout)
	button_layout.configure(self)
	game.get_viewport().size_changed.connect(layout)
	layout()
	refresh()

func _icon(id: String) -> Texture2D:
	var path := "res://art/ui/fullscreen/%s.svg" % id
	return load(path) if ResourceLoader.exists(path) else null

func _button(text: String, callback: Callable, icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme = theme
	b.theme_type_variation = "QuietButton"
	b.icon = _icon(icon) if icon != "" else null
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width",24)
	b.focus_mode = Control.FOCUS_NONE
	if callback.is_valid():
		b.pressed.connect(callback)
	game.get_node("HUD").add_child(b)
	return b

func _mobile_button(text: String, callback: Callable, primary := false) -> MobileButton:
	var b := MobileButton.new()
	b.ui = self
	b.primary = primary
	b.text = text
	b.theme = theme
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	# Native Button owns focus/touch/style; draw the icon and text vertically.
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		b.add_theme_color_override(state,Color.TRANSPARENT)
	for state in ["normal","hover","pressed","disabled"]:
		var style: StyleBoxFlat = theme.get_stylebox(state,"Button").duplicate()
		style.set_corner_radius_all(20 if primary else 14)
		if primary and state != "disabled":
			style.border_color = Color("328b82")
			style.set_border_width_all(3)
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(callback)
	game.get_node("HUD").add_child(b)
	return b

func toggle_bag() -> void:
	if game.phase != "playing" or (game.world_input_blocked() and not game.shop_panel.panel.visible):
		return
	bag_open = not bag_open
	refresh_inventory()

func _paper(id: String) -> Panel:
	var p := Panel.new()
	p.name = id
	p.theme = theme
	p.add_theme_stylebox_override("panel",theme.get_stylebox("panel","HudPanel"))
	game.get_node("HUD").add_child(p)
	return p

func safe_area() -> Rect2:
	var size: Vector2 = game.get_viewport_rect().size
	# Convert physical display safe insets to the canvas, never to world units.
	var inset := Vector4(16,16,16,20)
	if OS.has_feature("mobile"):
		var physical := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		var scale := size/physical
		inset += Vector4(safe.position.x*scale.x,safe.position.y*scale.y,(physical.x-safe.end.x)*scale.x,(physical.y-safe.end.y)*scale.y)
	return Rect2(Vector2(inset.x,inset.y),size-Vector2(inset.x+inset.z,inset.y+inset.w))

func layout() -> void:
	if not game or not menu:
		return
	var safe := safe_area()
	if button_layout and button_layout.editing and last_size != game.get_viewport_rect().size:
		button_layout.end_drag()
	last_size = game.get_viewport_rect().size
	clock.position = safe.position
	clock.size = Vector2(300,100)
	routine_button.position = safe.position+Vector2(308,0)
	routine_button.size = Vector2(124,48)
	sleep_button.position = safe.position+Vector2(308,56)
	sleep_button.size = Vector2(148,48)
	menu_button.position = Vector2(safe.end.x-52,safe.position.y)
	menu_button.size = Vector2(52,52)
	wallet.position = menu_button.position-Vector2(106,0)
	wallet.size = Vector2(98,52)
	goal.position = wallet.position-Vector2(142,0)
	goal.size = Vector2(134,52)
	var map_width := 200.0 if safe.size.x < 1040 else 220.0
	var map_height := 160.0 if safe.size.x < 1040 else 174.0
	game.mini_map.position = Vector2(safe.end.x-map_width,safe.position.y+64)
	game.mini_map.size = Vector2(map_width,map_height)
	game.mini_map.locate_button.position = Vector2(10,map_height-52)
	game.mini_map.locate_button.size = Vector2(map_width-96,48)
	game.mini_map.locate_button.text = "定位"
	game.mini_map.locate_button.icon = _icon("locate")
	game.mini_map.locate_button.add_theme_constant_override("icon_max_width",22)
	map_collapse.position = Vector2(map_width-78,map_height-52)
	map_collapse.size = Vector2(68,48)
	map_toggle.position = Vector2(safe.end.x-94,safe.position.y+64)
	map_toggle.size = Vector2(94,48)
	var pad_size := 120.0 if safe.size.x < 1040 else 136.0
	var pad: Control = game.mobile_controls.pad
	pad.position = Vector2(safe.position.x+8,safe.end.y-pad_size-12)
	pad.size = Vector2(pad_size,pad_size)
	var card_height := 82.0
	var card_top := pad.position.y-12-3*card_height-16
	for index in range(3):
		game.cards[index].position = Vector2(safe.position.x,card_top+index*(card_height+8))
		game.cards[index].size = Vector2(164,card_height)
		faces[index].size = game.cards[index].size
	action_button.size = Vector2(104,104)
	action_button.position = safe.end-action_button.size-Vector2(40,32)
	ability_button.size = Vector2(72,64)
	bag_button.size = Vector2(72,64)
	bag_button.position = Vector2(action_button.position.x+32,action_button.position.y-76)
	ability_button.position = bag_button.position-Vector2(84,0)
	target_button.size = Vector2(56,48)
	target_button.position = Vector2(action_button.position.x-68,action_button.position.y+28)
	if button_layout:
		button_layout.remember_defaults()
		button_layout.apply_positions()
	menu.position = safe.get_center()-menu.size/2
	for blocker in [menu_blocker,game.shop_panel.blocker,game.schedule.blocker,game.schedule.result_blocker,game.developer_settings.blocker,game.routine_panel.blocker]:
		blocker.position = Vector2.ZERO
		blocker.size = last_size
	for p in [game.shop_panel.panel,game.schedule.panel,game.schedule.result_panel,game.developer_settings.panel,game.routine_panel.panel]:
		p.position = safe.get_center()-p.size/2
		for child in p.get_children():
			if child is Button:
				child.size.y = maxf(48,child.size.y)
	game.routine_panel.layout(safe)
	toast.size = Vector2(360,56)
	toast.position = Vector2(safe.get_center().x-toast.size.x/2,safe.end.y-toast.size.y)
	game.status_label.position = Vector2(12,7)
	game.status_label.size = toast.size-Vector2(24,14)
	game.map_camera.reset()
	refresh_inventory()

func refresh_inventory() -> void:
	if not inventory_paper:
		return
	var inv = game.inventory_panel
	var capacity: int = game.inventory.capacity(game.selected_actor_id)
	var has_item: bool = game.inventory.owns(game.selected_actor_id,inv.selected_item)
	var actions: bool = has_item and not game.world_input_blocked()
	var shop_open: bool = game.shop_panel.panel.visible
	var width := 212 if shop_open or not actions else 284
	var safe := safe_area()
	inventory_paper.size = Vector2(width,132+(112 if actions else 0))
	var bottom: float = safe.end.y if shop_open else bag_button.position.y-12
	inventory_paper.position = Vector2(safe.end.x-width,maxf(safe.position.y+112,bottom-inventory_paper.size.y))
	inv.label.position = Vector2(14,18)
	inv.label.size = Vector2(width-82,32)
	inv.label.text = "伙伴 %d · %d/%d" % [game.selected_actor_id+1,game.inventory.items(game.selected_actor_id).size(),capacity]
	for index in range(inv.slots.size()):
		var slot: Button = inv.slots[index]
		slot.position = Vector2(14+index*64,62)
		slot.size = Vector2(56,56)
		slot.visible = index < capacity
		slot.disabled = game.phase != "playing" or game.actors[game.selected_actor_id].escaped or (game.world_input_blocked() and not shop_open)
		slot.theme = theme
		slot.theme_type_variation = "InventorySlot"
		slot.add_theme_constant_override("icon_max_width",38)
	game.mini_map.stop_button.position = Vector2(width-62,8)
	game.mini_map.stop_button.size = Vector2(48,48)
	game.mini_map.stop_button.disabled = game.world_input_blocked() or game.actors[game.selected_actor_id].escaped
	var buttons: Array = [inv.use_button,inv.drop_button]
	for receiver in range(inv.transfer_buttons.size()):
		var transfer: Button = inv.transfer_buttons[receiver]
		transfer.visible = actions and receiver != game.selected_actor_id
		if receiver != game.selected_actor_id:
			buttons.append(transfer)
	for index in range(buttons.size()):
		var b: Button = buttons[index]
		b.visible = actions
		b.position = Vector2(14+(index%2)*(width-28)/2,132+floori(index/2.0)*56)
		b.size = Vector2((width-36)/2,48)
	position_toast()
	inventory_paper.visible = (bag_open or shop_open) and not game.routine_panel.panel.visible and not menu.visible and not game.schedule.panel.visible and not game.developer_settings.panel.visible and game.phase == "playing"

func position_toast() -> void:
	var safe := safe_area()
	var left: float = game.cards[0].position.x+game.cards[0].size.x+16
	var right: float = maxf(left+120,target_button.position.x-12)
	var width: float = minf(360,maxf(120,right-left))
	toast.size = Vector2(width,56)
	toast.position = Vector2(clampf(safe.get_center().x-width/2,left,right-width),safe.end.y-56)
	for control in [game.mobile_controls.pad,action_button,ability_button,bag_button,target_button]:
		if toast.get_global_rect().intersects(control.get_global_rect()):
			toast.position.y = minf(toast.position.y,control.position.y-toast.size.y-8)
	game.status_label.size = toast.size-Vector2(24,14)

func refresh() -> void:
	if not clock:
		return
	var planning: bool = game.routine_panel.panel.visible
	var blocked: bool = game.world_input_blocked()
	var actor = game.actors[game.selected_actor_id]
	var active: bool = not blocked and not actor.escaped
	# z_index alone does not determine Control input order; hide the covered
	# global entry as well, so the last HUD child cannot intercept planner taps.
	menu_button.z_index = 120 if planning else 240
	menu_button.visible = not blocked or menu.visible
	clock.queue_redraw()
	clock.disabled = blocked
	routine_button.disabled = game.phase != "playing"
	routine_button.visible = not game.world_input_blocked()
	routine_button.text = "日常表"
	sleep_button.visible = game.schedule.is_sleep_time() and game.phase == "playing" and not game.world_input_blocked()
	sleep_button.disabled = not game.schedule.can_skip_night()
	sleep_button.tooltip_text = game.schedule.skip_button.tooltip_text
	goal.text = "逃脱 %d/3" % game.actors.filter(func(a): return a.escaped).size()
	wallet.text = str(game.inventory.wallet)
	for face in faces:
		face.queue_redraw()
	for index in range(game.cards.size()):
		var card = game.cards[index]
		card.icon = null
		card.text = ""
		card.disabled = blocked or game.actors[index].escaped
	var interaction = game.presentation.interaction
	action_button.text = interaction.mobile_label()
	action_button.display_icon = interaction.mobile_icon()
	action_button.disabled = not active or not interaction.mobile_available()
	action_button.visible = not blocked
	action_button.queue_redraw()
	ability_button.text = "停止技能" if game.skill_button.text.begins_with("停止") else game.SKILL_NAMES[actor.skill_id]
	ability_button.tooltip_text = game.skill_button.text
	ability_button.display_icon = game.items_view.icon_for("backpack") if actor.skill_id == "backpack" else game.presentation.skill_icons.get(actor.skill_id)
	ability_button.disabled = not active or game.skill_button.disabled
	ability_button.visible = not blocked
	ability_button.queue_redraw()
	bag_button.text = "背包\n%d/%d" % [game.inventory.items(game.selected_actor_id).size(),game.inventory.capacity(game.selected_actor_id)]
	bag_button.disabled = not active
	bag_button.visible = not blocked
	bag_button.queue_redraw()
	target_button.visible = active and interaction.mobile_target_count() > 1
	target_button.disabled = not active
	game.skill_button.hide()
	game.mobile_controls.pad.visible = active
	if not active:
		game.mobile_controls.cancel_input()
	refresh_inventory()
	map_toggle.visible = minimap_collapsed and not game.world_input_blocked()
	toast.visible = game.elapsed < game.status_until and not game.world_input_blocked()
	game.status_label.visible = toast.visible

func toggle_menu() -> void:
	if button_layout and button_layout.editing:
		return
	if menu.visible:
		close_menu()
	else:
		game.routine_panel.close()
		game.shop_panel.close()
		game.schedule.close()
		game.developer_settings.close()
		menu.show()
		menu_blocker.show()
		game.get_tree().paused = true
		game.presentation.interaction.refresh()
		refresh()

func close_menu() -> void:
	if menu:
		menu.hide()
		menu_blocker.hide()
	if game:
		game.get_tree().paused = game.routine_panel != null and game.routine_panel.panel.visible
		refresh()

func _process(_delta: float) -> void:
	if game:
		if last_size != game.get_viewport_rect().size:
			layout()
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if game.routine_panel.panel.visible:
			if game.routine_panel.picker.visible:
				game.routine_panel.close_picker()
			else:
				game.routine_panel.close()
		elif game.shop_panel.panel.visible:
			game.shop_panel.close()
		elif game.schedule.panel.visible:
			game.schedule.close()
		elif game.developer_settings.panel.visible:
			game.developer_settings.close()
		else:
			toggle_menu()
		game.get_viewport().set_input_as_handled()
