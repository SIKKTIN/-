extends Node2D

const Prisoner = preload("res://scripts/actors/prisoner.gd")
const World = preload("res://scripts/world/prison_world.gd")
const Guard = preload("res://scripts/actors/guard.gd")
const Skills = preload("res://scripts/skills/skill_controller.gd")
const Presentation = preload("res://scripts/presentation/game_presentation.gd")
const MoveOrders = preload("res://scripts/core/move_orders.gd")
const TextureTiles = preload("res://scripts/presentation/texture_tiles.gd")
const Inventory = preload("res://scripts/items/inventory.gd")
const InventoryPanel = preload("res://scripts/ui/inventory_panel.gd")
const Trade = preload("res://scripts/items/trade.gd")
const ItemsView = preload("res://scripts/presentation/items_view.gd")
const ShopPanel = preload("res://scripts/ui/shop_panel.gd")
const MapCamera = preload("res://scripts/core/map_camera.gd")
const MiniMap = preload("res://scripts/ui/mini_map.gd")
const DailyRoutine = preload("res://scripts/core/daily_routine.gd")
const RoutinePanel = preload("res://scripts/ui/routine_panel.gd")
const PrisonSchedule = preload("res://scripts/core/prison_schedule.gd")
const PoliceDog = preload("res://scripts/actors/police_dog.gd")
const FullscreenHUD = preload("res://scripts/ui/fullscreen_hud.gd")
const DeveloperSettings = preload("res://scripts/ui/developer_settings.gd")
const ROOM := Rect2(74, 114, 922, 560)
const STARTS := [Vector2(180, 235), Vector2(235, 375), Vector2(185, 510)]
const ACTOR_RADIUS := 17.0
const MOVE_SPEED := 260.0
const SKILL_NAMES := {"chat": "会聊天", "lockpick": "会撬锁", "strong": "大力气", "backpack": "会收纳"}
const ROOM_IDS := ["r01", "r02", "r03", "r04"]
var inventory
var inventory_panel
var room_config: Dictionary = {}
var trade
var items_view
var shop_panel
var map_camera
var mini_map
var schedule
var dog
var developer_settings
var routines
var routine_panel
var fullscreen_ui

var actors: Array = []
var selected_actor_id: int = 0
var orders
var status_text: String = "轻点选人或空地移动，拖动主图/小地图查看房间。"
var cards: Array[Button] = []
var status_label: Label
var phase: String = "playing"
var elapsed: float = 0.0
var guard_position := Vector2(735, 280)
var world
var guard
var captures: int = 0
var skills
var skill_button: Button
var hint_label: Label
var status_until: float = 0.0
var deal_seed: int = 0
var deal_number: int = 0
var room_selector: OptionButton
var presentation
var floor_texture: Texture2D
var floor_tile_size: int = 40
var perspective_floor: bool = false
@export var room_id: String = "r01"

func _ready() -> void:
	# The floor shares the prefiltered static-world textures; character sheets
	# retain their existing linear sampling (they have no mipmap chain).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for index in range(3):
		var actor = Prisoner.new()
		actor.name = "Prisoner%d" % (index + 1)
		actor.actor_id = index
		actor.home = STARTS[index]
		actor.skill_id = ["chat", "lockpick", "strong"][index]
		add_child(actor)
		actors.append(actor)
	world = World.new()
	world.name = "World"
	add_child(world)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/%s.json" % room_id))
	room_config = config
	world.configure(config,actors)
	for index in range(actors.size()):
		var start: Array = config.starts[index]
		actors[index].home = Vector2(start[0],start[1])
	guard = Guard.new()
	guard.name = "Guard"
	add_child(guard)
	guard.configure(world,self)
	dog = PoliceDog.new()
	dog.name = "PoliceDog"
	add_child(dog)
	dog.configure(self)
	skills = Skills.new(self)
	orders = MoveOrders.new(self)
	inventory = Inventory.new(self)
	trade = Trade.new(self)
	_build_ui()
	reset_round()
	presentation = Presentation.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.configure(self)
	items_view = ItemsView.new()
	items_view.name = "ItemsView"
	add_child(items_view)
	items_view.configure(self)
	inventory_panel = InventoryPanel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	inventory_panel.configure(self)
	shop_panel = ShopPanel.new()
	shop_panel.name = "ShopPanel"
	add_child(shop_panel)
	shop_panel.configure(self)
	map_camera = MapCamera.new()
	map_camera.name = "MapCamera"
	add_child(map_camera)
	map_camera.configure(self)
	mini_map = MiniMap.new()
	mini_map.name = "MiniMap"
	get_node("HUD").add_child(mini_map)
	mini_map.configure(self)
	schedule = PrisonSchedule.new()
	schedule.name = "Schedule"
	add_child(schedule)
	schedule.configure(self)
	developer_settings = DeveloperSettings.new()
	developer_settings.name = "DeveloperSettings"
	add_child(developer_settings)
	developer_settings.configure(self)
	routines = DailyRoutine.new(self)
	routines.tick()
	routine_panel = RoutinePanel.new()
	add_child(routine_panel)
	routine_panel.configure(self)
	fullscreen_ui = FullscreenHUD.new()
	add_child(fullscreen_ui)
	fullscreen_ui.configure(self)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var title := Label.new()
	title.text = "这次怎么逃"
	title.position = Vector2(32, 25)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("303b46"))
	layer.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "随机技能 · 独立背包 · 搬货交易，配合逃脱"
	subtitle.position = Vector2(34, 70)
	subtitle.add_theme_color_override("font_color", Color("536052"))
	layer.add_child(subtitle)
	room_selector = OptionButton.new()
	room_selector.name = "RoomSelector"
	room_selector.z_index = 210 # Remains usable above a terminal result overlay.
	room_selector.position = Vector2(566,35)
	room_selector.size = Vector2(230,42)
	for index in range(ROOM_IDS.size()):
		room_selector.add_item(["R01 · 双通路", "R02 · 门边掩护", "R03 · 仓库交易所", "R04 · 监区生活层"][index])
		room_selector.set_item_disabled(index,not FileAccess.file_exists("res://data/rooms/%s.json" % ROOM_IDS[index]))
	room_selector.select(ROOM_IDS.find(room_id))
	room_selector.item_selected.connect(func(index): load_room(ROOM_IDS[index]))
	layer.add_child(room_selector)
	for index in range(3):
		var card := Button.new()
		card.name = "ActorCard%d" % (index + 1)
		card.position = Vector2(1025, 154 + index * 102)
		card.size = Vector2(155, 84)
		card.pressed.connect(select_actor.bind(index))
		layer.add_child(card)
		cards.append(card)
	var reset_button := Button.new()
	reset_button.name = "ResetRound"
	reset_button.text = "重新开始  R"
	reset_button.position = Vector2(1025, 62)
	reset_button.size = Vector2(155, 42)
	reset_button.pressed.connect(reset_round)
	layer.add_child(reset_button)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(34, 686)
	status_label.add_theme_color_override("font_color", Color("303b46"))
	layer.add_child(status_label)
	skill_button = Button.new()
	skill_button.name = "UseSkill"
	skill_button.position = Vector2(1025,474)
	skill_button.size = Vector2(155,48)
	skill_button.pressed.connect(use_selected_skill)
	layer.add_child(skill_button)
	hint_label = Label.new()
	hint_label.name = "SkillHint"
	hint_label.position = Vector2(1029,536)
	hint_label.size = Vector2(151,88)
	hint_label.max_lines_visible = 4
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color("536052"))
	layer.add_child(hint_label)

func _process(delta: float) -> void:
	if phase != "playing":
		if map_camera:
			map_camera.tick(delta)
		if presentation:
			presentation.tick(delta)
		return
	delta = minf(delta,schedule.real_remaining()) if schedule else delta
	elapsed += delta
	if schedule:
		schedule.advance(delta)
	for actor in actors:
		actor.moved_this_frame = false
	if routines:
		routines.tick()
	orders.tick(delta)
	skills.tick(delta)
	dog.tick(delta)
	guard.tick(delta)
	if schedule and phase == "playing" and schedule.remaining() <= 0:
		finish_timeout()
	guard_position = guard.position
	if map_camera:
		map_camera.tick(delta)
	if phase == "playing" and elapsed >= status_until:
		status_text = "逃脱 %d / 3 · 锁门%s · 抓回 %d 次 · 狱警%s" % [actors.filter(func(a): return a.escaped).size(),"已开" if world.door_open else "%d%%"%roundi(world.lock_progress*100),captures,"追击中" if guard.state == "chasing" else ("交谈中" if guard.state == "talking" else "巡逻中")]
	_update_ui()
	if presentation:
		presentation.tick(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_round()
			return
		if event.keycode == KEY_ESCAPE:
			if fullscreen_ui:
				fullscreen_ui.toggle_menu()
				return
			if shop_panel:
				shop_panel.close()
			if schedule:
				schedule.close()
			if developer_settings:
				developer_settings.close()
			return
	if world_input_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if not map_camera.view_rect().has_point(event.position):
			return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_at(point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			command_at(point)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			select_actor(event.keycode - KEY_1)
		elif event.keycode == KEY_E:
			presentation.interaction.activate_nearest()
		elif event.keycode == KEY_S:
			stop_selected()

func select_at(world_point: Vector2) -> bool:
	if phase != "playing":
		return false
	for index in range(actors.size() - 1, -1, -1):
		var actor = actors[index]
		var visual = actor.get_node_or_null("ArtVisual")
		var on_body: bool = visual != null and visual.body_bounds().has_point(world_point-actor.position)
		if not actor.escaped and (actor.position.distance_to(world_point) < 28 or on_body):
			select_actor(index)
			return true
	return false

func command_move(actor_id: int, target: Vector2) -> bool:
	var accepted: bool = orders.issue(actor_id,target)
	_update_ui()
	queue_redraw()
	return accepted

func command_at(point: Vector2) -> bool:
	if world.exit_area.has_point(point) or world.exit_icon_rect().has_point(point):
		point = world.exit_area.get_center() if world.bounds.encloses(world.exit_area) else Vector2(maxf(point.x,world.bounds.end.x+ACTOR_RADIUS+4),clampf(point.y,world.exit_area.position.y+ACTOR_RADIUS+1,world.exit_area.end.y-ACTOR_RADIUS-1))
	return command_move(selected_actor_id,point)

func stop_selected() -> void:
	if routines:
		routines.take_control(selected_actor_id)
	orders.stop(selected_actor_id)
	skills.cancel(selected_actor_id,"当前伙伴已停止操作，撬锁进度保留。")
	show_status("伙伴%d已停止。" % (selected_actor_id+1))
	_update_ui()

func on_actor_escaped(actor_id: int) -> void:
	inventory.carry_out(actor_id)
	if selected_actor_id == actor_id:
		for other in actors:
			if not other.escaped:
				select_actor(other.actor_id)
				break
	if actors.all(func(a): return a.escaped):
		phase = "complete"
		orders.clear()
		skills.clear_all()
		var carried: int = inventory.instances.values().filter(func(i): return i.location == "escaped").size()
		status_text = "三人全部逃脱！%.1f秒 · 抓回%d次 · 带出%d件 · 钱%d · R重开" % [elapsed,captures,carried,inventory.wallet]
		if schedule:
			schedule.show_result(true)

func select_actor(index: int) -> void:
	if index < 0 or index >= actors.size() or actors[index].escaped:
		return
	if selected_actor_id != index and shop_panel:
		shop_panel.close()
	selected_actor_id = index
	if map_camera:
		map_camera.following = true
	for actor in actors:
		actor.selected = actor.actor_id == index
		actor.queue_redraw()
	_update_ui()

func reset_round(fixed_skills: Array = [], seed_value: int = -1) -> void:
	if fullscreen_ui:
		fullscreen_ui.close_menu()
	phase = "playing"
	elapsed = 0
	status_until = 0
	captures = 0
	deal_number += 1
	deal_seed = randi() if seed_value < 0 else seed_value
	var random := RandomNumberGenerator.new()
	random.seed = deal_seed
	var choices: Array = room_config.get("skill_pool", ["chat","lockpick","strong"])
	if skills:
		skills.clear_all()
	if orders:
		orders.clear()
	for actor in actors:
		actor.reset_actor()
		actor.skill_id = str(fixed_skills[actor.actor_id]) if fixed_skills.size() == 3 else choices[random.randi_range(0,choices.size()-1)]
	if inventory:
		inventory.reset(room_config)
	if trade:
		trade.reset(room_config)
	if shop_panel:
		shop_panel.close()
	if inventory_panel:
		inventory_panel.selected_item = ""
	if world:
		world.reset_world()
	if guard:
		guard.reset_guard()
		guard_position = guard.position
	if dog:
		dog.reset_dog()
	if presentation:
		presentation.reset()
	if routines:
		routines.reset()
	if schedule:
		schedule.reset()
	if routines:
		routines.tick()
	if developer_settings:
		developer_settings.close()
	show_status("三天内让三人逃脱；日常表可安排伙伴工作和活动。",4)
	select_actor(0)
	if map_camera:
		map_camera.reset()
	_update_ui()
	queue_redraw()

func _update_ui() -> void:
	if cards.is_empty():
		return
	for index in range(actors.size()):
		var actor = actors[index]
		if not fullscreen_ui:
			var action_labels := {"idle":"待命","chatting":"交谈中","lockpicking":"撬锁中"}
			cards[index].text = "%s伙伴 %d\n%s\n%s" % ["● " if actor.selected else "", index + 1, SKILL_NAMES[actor.skill_id], "已逃脱" if actor.escaped else ("移动中" if orders and orders.active.has(index) else action_labels.get(actor.action_state,"待命"))]
			if schedule and schedule.is_curfew() and not actor.escaped and phase == "playing":
				var label: String = "寝室内" if schedule.in_dormitory(index) else "归寝中" if orders.active.has(index) and schedule.dormitory(index).has_point(orders.active[index].goal) else "宵禁外出！"
				cards[index].text = "%s伙伴 %d\n%s\n%s" % ["● " if actor.selected else "",index+1,SKILL_NAMES[actor.skill_id],label]
		cards[index].disabled = actor.escaped
	status_label.text = status_text
	if skill_button and skills:
		var actor = actors[selected_actor_id]
		var active: bool = skills.actions.has(selected_actor_id)
		var reason: String = "被动能力：背包增加至3格。" if actor.skill_id == "backpack" else skills.target_reason(actor)
		skill_button.text = "停止技能  E" if active else ("接触重箱自动推" if actor.skill_id == "strong" else "使用%s  E" % SKILL_NAMES[actor.skill_id])
		skill_button.disabled = phase != "playing" or actor.escaped or actor.skill_id == "strong" or (not active and reason != "")
		var no_opener: bool = actors.all(func(a): return a.skill_id == "chat") and trade.merchants.is_empty()
		hint_label.text = "全聊天：缺少开路技能，可按R重抽。" if no_opener else ("伙伴留在原地操作，可以换人行动。" if active else (reason if reason != "" else skills.library[actor.skill_id].description))
		if phase != "playing":
			hint_label.text = "已封监，点击重新开始。" if phase == "failed" else "全员已逃脱，点击重新开始。"
	if inventory_panel:
		inventory_panel.refresh()
	if shop_panel:
		shop_panel.refresh()
	if routine_panel:
		routine_panel.refresh()
	if fullscreen_ui:
		fullscreen_ui.refresh()
	if items_view:
		items_view.queue_redraw()

func _draw() -> void:
	var floor_area: Rect2 = world.bounds if world else ROOM
	var clip: Rect2 = floor_area
	if map_camera:
		clip = map_camera.world_view_rect()
	draw_rect(clip,Color("a6b2a3"))
	if floor_texture:
		var tile := Vector2(floor_tile_size,floor_tile_size)
		var origin := floor_area.position+((clip.position-floor_area.position)/tile).floor()*tile
		var painted := Rect2(origin,((clip.end-origin)/tile).ceil()*tile)
		TextureTiles.paint(self,floor_texture,painted,tile,clip)
	if not perspective_floor:
		for x in range(int(floor_area.position.x+20), int(floor_area.end.x), 40):
			draw_line(Vector2(x, floor_area.position.y+1), Vector2(x, floor_area.end.y-1), Color(0.2, 0.3, 0.25, 0.04))
		for y in range(int(floor_area.position.y+20), int(floor_area.end.y), 40):
			draw_line(Vector2(floor_area.position.x+1, y), Vector2(floor_area.end.x-1, y), Color(0.2, 0.3, 0.25, 0.04))
	if orders:
		for id in orders.active:
			var goal: Vector2 = orders.active[id].goal
			var color := Color("328b82") if id == selected_actor_id else Color("bc965a")
			draw_arc(goal,10,0,TAU,24,color,2,true)
			draw_line(goal-Vector2(14,0),goal+Vector2(14,0),color,1,true)
			draw_line(goal-Vector2(0,14),goal+Vector2(0,14),color,1,true)

func _floor_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("a6b2a3")
	style.border_color = Color("536052")
	style.set_border_width_all(5)
	return style

func snapshot() -> Dictionary:
	return {"phase": phase, "elapsed": elapsed, "selected_actor_id": selected_actor_id, "orders":orders.snapshot() if orders else [], "actors": actors.map(func(actor): return actor.snapshot()), "guard_position": [guard_position.x, guard_position.y],"guard":guard.snapshot() if guard else {},"world":world.snapshot() if world else {},"captures":captures,"seed":deal_seed,"deal":deal_number,"actions":skills.snapshot() if skills else [],"inventory":inventory.snapshot() if inventory else {}, "merchants": trade.snapshot() if trade else {}, "schedule":schedule.snapshot() if schedule else {},"routines":routines.snapshot() if routines else {},"dog":dog.snapshot() if dog else {}}

func world_input_blocked() -> bool:
	return phase != "playing" or get_tree().paused or (fullscreen_ui != null and fullscreen_ui.menu.visible) or (shop_panel != null and shop_panel.panel.visible) or (schedule != null and schedule.panel.visible) or (developer_settings != null and developer_settings.panel.visible) or (routine_panel != null and routine_panel.panel.visible)

func finish_timeout() -> void:
	phase = "failed"
	orders.clear()
	skills.clear_all()
	for actor in actors:
		actor.moved_this_frame = false
	guard.moved_this_frame = false
	dog.moved_this_frame = false
	status_text = "逃脱期限已到，行动结束。可重新开始。"
	schedule.show_result(false)

func capture_actor(actor_id: int) -> void:
	if routines:
		routines.take_control(actor_id)
	if shop_panel and shop_panel.actor_id == actor_id:
		shop_panel.close()
	var actor = actors[actor_id]
	if skills:
		skills.cancel(actor_id)
	actor.position = actor.home
	actor.action_state = "idle"
	actor.immune_until = elapsed + 1.0
	actor.queue_redraw()
	orders.stop(actor_id)
	captures += 1
	show_status("伙伴%d被送回起点；门、箱子、技能和已逃脱伙伴保留。" % (actor_id+1))

func show_status(text: String, duration: float = 2.5) -> void:
	status_text = text
	status_until = elapsed + duration

func use_selected_skill() -> void:
	if skills and skills.actions.has(selected_actor_id):
		skills.cancel(selected_actor_id, "已停止操作，撬锁进度保留。")
		return
	if actors[selected_actor_id].skill_id == "backpack":
		show_status("会收纳是被动能力：背包3格，无需使用技能。")
		return
	if skills and phase == "playing":
		if actors[selected_actor_id].skill_id == "strong" and presentation and presentation.interaction:
			presentation.interaction.activate(false)
			return
		if not skills.actions.has(selected_actor_id) and skills.target_reason(actors[selected_actor_id]) == "":
			orders.stop(selected_actor_id)
		skills.toggle(selected_actor_id)
		_update_ui()
		if presentation:
			presentation.tick(0)

func cancel_guard_chat(reason: String) -> void:
	if skills:
		skills.cancel_chat(reason)

func load_room(identifier: String, fixed_skills: Array = [], seed_value: int = -1) -> bool:
	var path := "res://data/rooms/%s.json" % identifier
	if not FileAccess.file_exists(path):
		show_status("这个房间还在制作。")
		return false
	if skills:
		skills.clear_all()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	room_config = config
	room_id = identifier
	world.configure(config,actors)
	for index in range(actors.size()):
		var start: Array = config.starts[index]
		actors[index].home = Vector2(start[0],start[1])
	guard.configure(world,self)
	if room_selector:
		room_selector.select(ROOM_IDS.find(identifier))
	reset_round(fixed_skills,seed_value)
	return true
