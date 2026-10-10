extends Node

const HudArt = preload("res://scripts/ui/hud_skin.gd")

class MobileButton extends Button:
	var ui
	var display_icon: Texture2D
	var primary := false
	func _draw() -> void:
		var ink := Color("303b46") if not disabled else Color("788176")
		var icon_size := 30.0
		if display_icon:
			draw_texture_rect(display_icon,Rect2((size.x-icon_size)/2,10,icon_size,icon_size),false,Color(1,1,1,0.45) if disabled else Color.WHITE)
		var font_size := 17
		var lines := text.split("\n")
		for row in range(lines.size()):
			var text_width: float = ui.font.get_string_size(lines[row],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			var baseline := size.y-10-(lines.size()-1-row)*16
			draw_string(ui.font,Vector2((size.x-text_width)/2,baseline),lines[row],HORIZONTAL_ALIGNMENT_LEFT,size.x-12,font_size,ink)
		HudArt.rivets(self,size)

var game
var font: Font
var theme: Theme
var clock
var goal: Button
var wallet: Button
var routine_button: Button
var sleep_button: Button
var menu_button: Button
var menu: Panel
var replay_tutorial: Button
var menu_blocker: ColorRect
var inventory_paper: Panel
var inventory_drawer
var toast: Panel
var faces: Array = []
var portraits: Array = []
var minimap_collapsed := true
var map_toggle: Button
var map_collapse: Button
var last_size := Vector2.ZERO
var action_button: MobileButton
var ability_button: MobileButton
var bag_button: MobileButton
var target_button: Button
var bag_open := false
var button_layout
var fps_badge: PanelContainer
var fps_label: Label
var fps_sample_time := -1000
var frame_mode: OptionButton
var warning_banner: Panel
var warning_title: Label
var warning_detail: Label
var warning_meter: ProgressBar
var warning_fill: StyleBoxFlat
var redraw_keys := {}

func redraw_changed(control: CanvasItem, key: Array):
	var id := control.get_instance_id()
	if redraw_keys.get(id,[])==key: return
	redraw_keys[id] = key
	control.queue_redraw()

func refresh_clock():
	if not clock or not game.prison_alert: return
	var schedule = game.schedule
	redraw_changed(clock,[floori(schedule.clock_minutes()),schedule.stage_index,clock.calendar_text(),schedule.time_left_text(),game.prison_alert.active,schedule.is_curfew(),schedule.real_remaining()<=30,clock.size])

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
	clock = preload("res://scripts/ui/player_clock.gd").new()
	clock.ui = self
	clock.theme = theme
	clock.focus_mode = Control.FOCUS_NONE
	clock.pressed.connect(func(): game.schedule.toggle())
	HudArt.button(clock)
	hud.add_child(clock)
	# Retain a hidden handle for older HUD consumers, without a menu entry.
	routine_button = _button("",Callable())
	routine_button.hide()
	routine_button.disabled = true
	sleep_button = _button("跳过夜晚",func(): game.schedule.skip_night())
	sleep_button.tooltip_text = "伙伴回各自床位并停止行动后，跳至次日07:20。"
	goal = _button("逃脱 0/1",Callable())
	goal.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet = _button("0",Callable(),"coin")
	fps_badge = PanelContainer.new()
	fps_badge.name = "RuntimeFPS"
	fps_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_badge.z_index = 50
	var fps_style := StyleBoxFlat.new()
	fps_style.bg_color = Color(0.13,0.19,0.18,0.82)
	fps_style.set_corner_radius_all(5)
	fps_style.set_content_margin_all(5)
	fps_badge.add_theme_stylebox_override("panel",fps_style)
	fps_label = Label.new()
	fps_label.name = "Value"
	fps_label.text = "FPS —"
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_override("font",font)
	fps_label.add_theme_font_size_override("font_size",14)
	fps_label.add_theme_color_override("font_color",Color("e4edda"))
	fps_badge.add_child(fps_label)
	hud.add_child(fps_badge)
	warning_banner = Panel.new()
	warning_banner.name = "SupervisionWarning"
	warning_banner.z_index = 70
	warning_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var warning_style := StyleBoxFlat.new()
	warning_style.bg_color = Color("f2dfd5")
	warning_style.border_color = Color("bc5348")
	warning_style.set_border_width_all(2)
	warning_style.set_corner_radius_all(8)
	warning_banner.add_theme_stylebox_override("panel",warning_style)
	for line in range(2):
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",19 if line == 0 else 13)
		label.add_theme_color_override("font_color",Color("943a31") if line == 0 else Color("713d34"))
		label.position = Vector2(12,5 if line == 0 else 33)
		warning_banner.add_child(label)
		if line == 0: warning_title = label
		else: warning_detail = label
	warning_meter = ProgressBar.new()
	warning_meter.name = "Suspicion"
	warning_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_meter.show_percentage = false
	var warning_track := StyleBoxFlat.new()
	warning_track.bg_color = Color("d7c3b6")
	warning_track.set_corner_radius_all(2)
	warning_fill = StyleBoxFlat.new()
	warning_fill.bg_color = Color("bc5348")
	warning_fill.set_corner_radius_all(2)
	warning_meter.add_theme_stylebox_override("background",warning_track)
	warning_meter.add_theme_stylebox_override("fill",warning_fill)
	warning_banner.add_child(warning_meter)
	hud.add_child(warning_banner)
	menu_button = _button("",toggle_menu,"pause")
	menu_button.z_index = 240
	menu_button.tooltip_text = "暂停 / 菜单"
	for index in range(3):
		var portrait: Texture2D = load("res://art/ui/fullscreen/portrait_%d.tres" % (index+1)) if ResourceLoader.exists("res://art/ui/fullscreen/portrait_%d.tres" % (index+1)) else null
		portraits.append(portrait)
		var card: Button = game.cards[index]
		card.text = ""
		card.icon = null
		HudArt.button(card)
		card.set_meta("base_style",HudArt.box("paper"))
		card.set_meta("selected_style",HudArt.box("paper"))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		var face = preload("res://scripts/ui/player_status.gd").new()
		face.ui = self
		face.index = index
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
		faces.append(face)
	inventory_drawer = preload("res://scripts/ui/inventory_drawer.gd").new()
	add_child(inventory_drawer)
	inventory_drawer.configure(self)
	inventory_paper = inventory_drawer.paper
	action_button = _mobile_button("互动",func(): game.presentation.interaction.activate_mobile(),true)
	action_button.name = "MobileInteraction"
	ability_button = _mobile_button("技能",game.use_selected_skill)
	ability_button.name = "MobileAbility"
	bag_button = _mobile_button("背包",toggle_bag)
	bag_button.name = "MobileBag"
	bag_button.display_icon = inventory_drawer.icon_for("backpack")
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
	menu = game.schedule._paper_panel("PauseMenu",Vector2.ZERO,Vector2(360,500),231)
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	game.schedule._label(menu,Vector2(24,20),"监狱风云 · 已暂停",22)
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
	restart.size = Vector2(148,48)
	replay_tutorial = game.schedule._button(menu,Vector2(184,238),"重玩教程",func():
		if game.tutorial and game.tutorial.eligible(): game.tutorial.replay()
		else: game.show_status("入监教程在工厂地图中提供。",3))
	replay_tutorial.name = "ReplayTutorial"
	replay_tutorial.size = Vector2(152,48)
	game.developer_settings.button.reparent(menu,false)
	game.developer_settings.button.position = Vector2(24,296)
	game.developer_settings.button.size = Vector2(312,48)
	game.developer_settings.button.pressed.disconnect(game.developer_settings.toggle)
	game.developer_settings.button.pressed.connect(func(): close_menu(); game.developer_settings.toggle())
	var layout_button: Button = game.schedule._button(menu,Vector2(24,352),"按键布局",func(): button_layout.open())
	layout_button.name = "EditButtonLayout"
	layout_button.size = Vector2(312,48)
	frame_mode=OptionButton.new()
	frame_mode.name="FrameRatePreset"
	frame_mode.theme=theme
	frame_mode.position=Vector2(24,410)
	frame_mode.size=Vector2(312,42)
	frame_mode.add_item("帧率：60帧 · 稳定模式",60)
	frame_mode.add_item("帧率：90帧 · 流畅模式",90)
	frame_mode.add_item("帧率：不限 · 性能测试",0)
	frame_mode.select(game.frame_settings.MODES.find(game.frame_settings.target_fps))
	frame_mode.tooltip_text="自动保存。90帧需要足够的设备性能；显示器刷新率会影响实际观感。"
	frame_mode.item_selected.connect(func(index):
		if not game.frame_settings.apply(frame_mode.get_item_id(index)):
			game.show_status("帧率模式已应用，本地保存失败。"))
	menu.add_child(frame_mode)
	game.schedule._label(menu,Vector2(24,466),"无辜被困 · 合作逃出黑工厂",14)
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
	HudArt.button(b)
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
	HudArt.button(b)
	for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		b.add_theme_color_override(color,Color.TRANSPARENT)
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
	var status_width := 246.0 if safe.size.x<1040 else 280.0
	clock.position = safe.position+Vector2(status_width+12,0)
	clock.size = Vector2(minf(500,safe.size.x-status_width-180),104)
	routine_button.position = safe.position+Vector2(308,0)
	routine_button.size = Vector2(124,48)
	sleep_button.position = safe.position+Vector2(status_width+12,112)
	sleep_button.size = Vector2(148,48)
	menu_button.position = Vector2(safe.end.x-52,safe.position.y)
	menu_button.size = Vector2(52,52)
	wallet.position = menu_button.position-Vector2(106,0)
	wallet.size = Vector2(98,52)
	goal.position = wallet.position-Vector2(142,0)
	goal.size = Vector2(134,52)
	fps_badge.position = safe.position+Vector2(0,112)
	fps_badge.size = Vector2(76,28)
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
	for index in range(3):
		game.cards[index].visible = index==0
		game.cards[index].position = safe.position
		game.cards[index].size = Vector2(status_width,104)
		faces[index].size = game.cards[index].size
	var warning_left: float = safe.position.x+status_width+12
	var warning_width: float = safe.end.x-warning_left-230
	if warning_width >= 320:
		warning_banner.position = Vector2(warning_left,safe.position.y+112)
		warning_banner.size = Vector2(minf(440,warning_width),68)
	else:
		warning_banner.size = Vector2(minf(400,safe.size.x-380),68)
		warning_banner.position = Vector2(safe.get_center().x-warning_banner.size.x/2,clock.position.y+clock.size.y+12)
	for label in [warning_title,warning_detail]: label.size = Vector2(warning_banner.size.x-24,28)
	warning_meter.position = Vector2(12,60)
	warning_meter.size = Vector2(warning_banner.size.x-24,4)
	action_button.size = Vector2(104,76)
	action_button.position = safe.end-action_button.size-Vector2(0,12)
	ability_button.size = Vector2(76,76)
	bag_button.size = Vector2(76,76)
	ability_button.position = action_button.position-Vector2(88,0)
	bag_button.position = ability_button.position-Vector2(88,0)
	target_button.size = Vector2(56,48)
	target_button.position = action_button.position-Vector2(0,60)
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
	if inventory_drawer:
		inventory_drawer.refresh()
		position_toast()

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
	if game.tutorial and game.tutorial.panel.visible and toast.get_global_rect().intersects(game.tutorial.panel.get_global_rect()):
		toast.position.y = minf(toast.position.y,game.tutorial.panel.position.y-toast.size.y-8)
	game.status_label.size = toast.size-Vector2(24,14)

func refresh() -> void:
	if not clock or not game.attributes or not game.prison_alert:
		return
	var planning: bool = game.routine_panel.panel.visible
	var blocked: bool = game.world_input_blocked()
	var actor = game.actors[game.selected_actor_id]
	var active: bool = not blocked and not actor.escaped
	# z_index alone does not determine Control input order; hide the covered
	# global entry as well, so the last HUD child cannot intercept planner taps.
	menu_button.z_index = 120 if planning else 240
	menu_button.visible = not blocked or menu.visible or (game.tutorial and game.tutorial.active and not game.tutorial.transition)
	refresh_clock()
	clock.disabled = blocked
	routine_button.hide()
	sleep_button.visible = game.schedule.is_sleep_time() and game.phase == "playing" and not game.world_input_blocked()
	sleep_button.disabled = not game.schedule.can_skip_night()
	sleep_button.tooltip_text = game.schedule.skip_button.tooltip_text
	goal.text = "逃脱 %d/1" % game.escape_count()
	goal.hide()
	if game.tutorial and game.tutorial.active: goal.text = "入监日 %d/6" % int(game.tutorial.step().get("chapter",1))
	wallet.text = str(game.inventory.wallet)
	var values: Dictionary = game.attributes.values[game.PLAYER_ACTOR_ID]
	redraw_changed(faces[0],[roundi(values.stamina),roundi(values.fullness),actor.skill_id,game.confinement_counts[0],faces[0].size])
	for index in range(game.cards.size()):
		var card = game.cards[index]
		card.visible = game.actor_is_controllable(index)
		card.icon = null
		card.text = ""
		card.disabled = blocked or game.actors[index].escaped or not game.actor_is_controllable(index)
		card.tooltip_text = "主角 · 玩家控制" if game.actor_is_controllable(index) else "自动囚徒 · 按默认日程生活，不能切换控制"
	var interaction = game.presentation.interaction
	action_button.text = interaction.mobile_label()
	action_button.display_icon = interaction.mobile_icon()
	if action_button.display_icon==null: action_button.display_icon = preload("res://art/ui/fullscreen/interaction.svg")
	action_button.disabled = not active or not interaction.mobile_available()
	action_button.visible = not blocked
	redraw_changed(action_button,[action_button.text,action_button.display_icon,action_button.disabled,action_button.size])
	ability_button.text = "停止" if game.skill_button.text.begins_with("停止") else "能力"
	ability_button.tooltip_text = game.skill_button.text
	ability_button.display_icon = inventory_drawer.icon_for("backpack") if actor.skill_id == "backpack" else game.presentation.skill_icons.get(actor.skill_id)
	ability_button.disabled = not active or game.skill_button.disabled
	ability_button.visible = not blocked
	redraw_changed(ability_button,[ability_button.text,ability_button.display_icon,ability_button.disabled,ability_button.size])
	bag_button.text = "背包"
	bag_button.tooltip_text = "随身背包 %d/%d" % [game.inventory.items(0).size(),game.inventory.capacity(0)]
	bag_button.disabled = not active
	bag_button.visible = not blocked
	redraw_changed(bag_button,[bag_button.text,bag_button.display_icon,bag_button.disabled,bag_button.size])
	var bag_style: StyleBoxFlat = HudArt.box("selected" if bag_open else "paper")
	if bag_button.get_theme_stylebox("normal")!=bag_style: bag_button.add_theme_stylebox_override("normal",bag_style)
	target_button.visible = active and interaction.mobile_target_count() > 1
	target_button.disabled = not active
	game.skill_button.hide()
	game.mobile_controls.pad.visible = active
	if not active:
		game.mobile_controls.cancel_input()
	refresh_inventory()
	if inventory_paper.visible: minimap_collapsed = true
	game.mini_map.set_process_input(not minimap_collapsed and not inventory_paper.visible)
	map_toggle.visible = minimap_collapsed and not game.world_input_blocked()
	if inventory_paper.visible:
		game.mini_map.hide()
		map_toggle.visible = map_toggle.visible and not map_toggle.get_rect().intersects(inventory_paper.get_rect())
	toast.visible = game.elapsed < game.status_until and not game.world_input_blocked()
	game.status_label.visible = toast.visible
	refresh_warning(blocked)
	if game.tutorial:
		replay_tutorial.visible = not game.tutorial.active
		game.tutorial.sync_visibility()

func refresh_warning(blocked: bool) -> void:
	var title := ""
	var detail := ""
	var recovering := false
	warning_meter.hide()
	var id: int = game.PLAYER_ACTOR_ID
	if game.workshop and game.workshop.on_duty() and not game.actors[id].confined and not game.actors[id].escaped:
		var count: int = game.workshop.chase_count(id)
		recovering = game.workshop.warning_recovering(id)
		if game.workshop.warnings.has(id) or game.workshop.wanted.has(id):
			warning_meter.max_value = game.workshop.warning_seconds()
			warning_meter.value = game.workshop.warning_level(id)
			warning_meter.show()
		if count > 0 or game.workshop.wanted.has(id):
			title = "！正在被追捕"
			detail = "%d名看守正在追捕 · 被抓关禁闭2小时" % count if count > 0 else "监工搜捕中 · 回工位继续劳动"
			if recovering: detail = "持续工作 %.1f秒后解除监管 · 警戒消退中" % game.workshop.recovery_seconds(id)
		elif game.workshop.outside_violation(id):
			title = "！脱离劳动监管"
			detail = "劳动时间禁止外出 · 看守发现会立即抓捕"
		elif game.workshop.warnings.has(id):
			title = "监管恢复中 · 还需%.1f秒" % game.workshop.recovery_seconds(id) if recovering else "！监工警告 · %.1f秒后追捕" % game.workshop.warning_remaining(id)
			detail = "保持工作，警戒缓慢消退 · 停工继续倒计时" if recovering else "回自己的工位工作 · 躲开视线不会停止倒计时"
	warning_fill.bg_color = Color("318f83") if recovering else Color("bc5348")
	warning_title.text = title
	warning_detail.text = detail
	warning_banner.visible = not title.is_empty() and not blocked and game.phase == "playing"

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
		# Wall-clock sampling keeps debug FPS independent of simulation speed
		# and running when the daily planner or pause menu stops gameplay.
		var now := Time.get_ticks_msec()
		if now-fps_sample_time >= 250:
			fps_sample_time = now
			var fps := Engine.get_frames_per_second()
			fps_label.text = "FPS %d" % fps if fps > 0 else "FPS —"
			fps_badge.tooltip_text="目标：%s；物理与日程速度保持一致。" % ("不限帧" if game.frame_settings.target_fps==0 else "%d帧" % game.frame_settings.target_fps)
		if last_size != game.get_viewport_rect().size:
			layout()
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if game.dialogue and game.dialogue.panel.visible:
			game.dialogue.close()
		elif game.routine_panel.panel.visible:
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
