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
const PrisonSchedule = preload("res://scripts/core/prison_schedule.gd")
const PoliceDog = preload("res://scripts/actors/police_dog.gd")
const FullscreenHUD = preload("res://scripts/ui/fullscreen_hud.gd")
const StaffTraffic = preload("res://scripts/core/staff_traffic.gd")
const GateWatch = preload("res://scripts/core/gate_watch.gd")
const ActorAttributes = preload("res://scripts/core/actor_attributes.gd")
const DeveloperSettings = preload("res://scripts/ui/developer_settings.gd")
const PrisonAlert = preload("res://scripts/core/prison_alert.gd")
const MobileControls = preload("res://scripts/core/mobile_controls.gd")
const RoomAccess = preload("res://scripts/core/room_access.gd")
const WorkshopRules = preload("res://scripts/core/workshop_rules.gd")
const NpcDialogue = preload("res://scripts/ui/npc_dialogue.gd")
const TutorialDay = preload("res://scripts/core/tutorial_day.gd")
const ROOM := Rect2(74, 114, 922, 560)
const STARTS := [Vector2(180, 235), Vector2(235, 375), Vector2(185, 510)]
const ACTOR_RADIUS := preload("res://scripts/core/actor_footprint.gd").RADIUS
const MOVE_SPEED := 260.0
const PLAYER_ACTOR_ID := 0
const SKILL_NAMES := {"chat": "会聊天", "lockpick": "会撬锁", "strong": "大力气", "backpack": "会收纳"}
const ROOM_IDS := ["r01", "r02", "r03", "r04"]
var inventory
var quick_items
var map_viewer
var inventory_panel
var looting
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
var fullscreen_ui
var staff_traffic
var gate_watch
var attributes
var prison_alert
var mobile_controls
var room_visibility
var room_access
var workshop
var dialogue
var tutorial
var social
var npc_life
var bath_service
var resident_staff
var confinement_counts: Array[int] = [0,0,0]
var failure_reason := ""
var editor_preview_mode := false
var frame_settings

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
var status_until: float = 0.0
var deal_seed: int = 0
var deal_number: int = 0
var room_selector: OptionButton
var presentation
var floor_texture: Texture2D
var floor_tile_size: int = 40
var perspective_floor: bool = false
@export var room_id: String = "r01"

func _make_world():
	return World.new()

func _ready() -> void:
	preload("res://scripts/core/game_bootstrap.gd").configure(self)

func _build_ui() -> void:
	preload("res://scripts/ui/hud_shell.gd").configure(self)

func _process(delta: float) -> void:
	preload("res://scripts/core/game_frame.gd").tick(self,delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_round()
			return
		if event.keycode == KEY_ESCAPE:
			if map_viewer and map_viewer.is_open():
				map_viewer.close()
				return
			if fullscreen_ui and fullscreen_ui.bag_open:
				fullscreen_ui.bag_open = false
				_update_ui()
				return
			if looting and looting.is_open():
				looting.close()
				_update_ui()
				return
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
		elif event.button_index == MOUSE_BUTTON_RIGHT and mobile_controls == null:
			command_at(point)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			quick_items.activate(event.keycode - KEY_1)
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
	if not actor_is_controllable(actor_id): return false
	var accepted: bool = orders.issue(actor_id,target)
	_update_ui()
	queue_redraw()
	return accepted

func command_at(point: Vector2) -> bool:
	var expanded_exit: Variant = world.escape_target(point)
	if expanded_exit is Vector2:
		return command_move(selected_actor_id,expanded_exit)
	if world.exit_area.has_point(point) or world.exit_icon_rect().has_point(point):
		point = world.exit_area.get_center() if world.bounds.encloses(world.exit_area) else Vector2(maxf(point.x,world.bounds.end.x+ACTOR_RADIUS+4),clampf(point.y,world.exit_area.position.y+ACTOR_RADIUS+1,world.exit_area.end.y-ACTOR_RADIUS-1))
	return command_move(selected_actor_id,point)

func stop_selected() -> void:
	if not actor_is_controllable(selected_actor_id): return
	if mobile_controls:
		mobile_controls.cancel_input()
	if routines:
		routines.take_control(selected_actor_id)
	orders.stop(selected_actor_id)
	skills.cancel(selected_actor_id,"当前伙伴已停止操作，撬锁进度保留。")
	if bath_service: bath_service.cancel(selected_actor_id)
	show_status("伙伴%d已停止。" % (selected_actor_id+1))
	_update_ui()

func on_actor_escaped(actor_id: int) -> void:
	if tutorial and tutorial.active:
		actors[actor_id].escaped = false
		orders.stop(actor_id)
		show_status("入监日先熟悉作息；正式%d天开始后再寻找逃脱机会。" % schedule.escape_days,4)
		return
	inventory.carry_out(actor_id)
	if actors[PLAYER_ACTOR_ID].escaped:
		if looting: looting.close()
		phase = "complete"
		orders.clear()
		skills.clear_all()
		var carried: int = inventory.instances.values().filter(func(i): return i.location == "escaped").size()
		status_text = "主角逃脱成功！%.1f秒 · 抓回%d次 · 带出%d件 · 钱%d · R重开" % [elapsed,captures,carried,inventory.wallet]
		if schedule:
			schedule.show_result(true)

func actor_is_controllable(index: int) -> bool:
	return index == PLAYER_ACTOR_ID and index >= 0 and index < actors.size()

func escape_count() -> int:
	return 1 if actors[PLAYER_ACTOR_ID].escaped else 0

func select_actor(index: int) -> void:
	if not actor_is_controllable(index) or actors[index].escaped:
		return
	if mobile_controls:
		mobile_controls.cancel_input()
	if selected_actor_id != index and shop_panel:
		shop_panel.close()
	selected_actor_id = index
	if map_camera:
		map_camera.following = true
	for actor in actors:
		actor.selected = actor.actor_id == index
		actor.queue_redraw()
	if presentation and presentation.interaction:
		presentation.interaction.refresh()
	_update_ui()

func reset_round(fixed_skills: Array = [], seed_value: int = -1) -> void:
	if looting: looting.close()
	if map_viewer: map_viewer.reset()
	if quick_items: quick_items.reset()
	if tutorial: tutorial.cancel()
	if fullscreen_ui:
		fullscreen_ui.close_menu()
		fullscreen_ui.bag_open = false
	if mobile_controls:
		mobile_controls.cancel_input()
	phase = "playing"
	elapsed = 0
	status_until = 0
	captures = 0
	confinement_counts = [0,0,0]
	failure_reason = ""
	if dialogue: dialogue.close()
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
	if staff_traffic:
		staff_traffic.reset()
	if prison_alert:
		prison_alert.reset()
	if world:
		world.reset_world()
	if looting: looting.reset()
	if room_access:
		room_access.reset()
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
		if tutorial and tutorial.completed and tutorial.eligible():
			schedule.calendar_day_offset = 1
			schedule.tick(false)
	if room_visibility: room_visibility.reset()
	if resident_staff: resident_staff.reset()
	if bath_service: bath_service.reset()
	if gate_watch:
		gate_watch.reset(room_config)
	if attributes:
		attributes.reset()
	if workshop:
		workshop.reset()
	if social: social.reset()
	if npc_life: npc_life.reset()
	if room_access:
		room_access.tick()
	if routines:
		routines.tick()
	if developer_settings:
		developer_settings.close()
	show_status("你的移动、工作、吃饭和归寝都由你决定；NPC 按各自状态生活。",4)
	select_actor(0)
	if map_camera:
		map_camera.reset()
	if tutorial: tutorial.on_round_reset()
	_update_ui()
	queue_redraw()

func _update_ui(refresh_hud := true) -> void:
	if status_label:
		status_label.text = status_text
	if inventory_panel:
		inventory_panel.refresh()
	if shop_panel:
		shop_panel.refresh()
	if fullscreen_ui and refresh_hud:
		fullscreen_ui.refresh()
	if items_view:
		items_view.queue_redraw()

func paint_floor(canvas: CanvasItem, clip: Rect2) -> void:
	var floor_area: Rect2 = world.bounds if world else ROOM
	canvas.draw_rect(clip,Color("a6b2a3"))
	if floor_texture:
		var tile := Vector2(floor_tile_size,floor_tile_size)
		var origin := floor_area.position+((clip.position-floor_area.position)/tile).floor()*tile
		var painted := Rect2(origin,((clip.end-origin)/tile).ceil()*tile)
		TextureTiles.paint(canvas,floor_texture,painted,tile,clip)
	preload("res://scripts/presentation/region_terrain.gd").paint(canvas,room_config,clip)

func _draw() -> void:
	var floor_area: Rect2 = world.bounds if world else ROOM
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

func inspection_positions() -> Array:
	var team: Array = prison_alert.officers() if prison_alert else [guard]
	return team.filter(func(g): return g.inspection_allowed() and not g.escaped).map(func(g): return g.position)

func snapshot() -> Dictionary:
	var alarm: Dictionary = prison_alert.snapshot() if prison_alert else {}
	return {"bath_service":bath_service.snapshot() if bath_service else {},"room_access":room_access.snapshot() if room_access else {},"prison_alert":alarm,"phase": phase, "elapsed": elapsed, "selected_actor_id": selected_actor_id, "orders":orders.snapshot() if orders else [], "actors": actors.map(func(actor): return actor.snapshot()), "guard_position": [guard_position.x, guard_position.y],"guard":guard.snapshot() if guard else {},"world":world.snapshot() if world else {},"captures":captures,"confinement_counts":confinement_counts.duplicate(),"failure_reason":failure_reason,"dialogue":dialogue.snapshot() if dialogue else {},"seed":deal_seed,"deal":deal_number,"actions":skills.snapshot() if skills else [],"inventory":inventory.snapshot() if inventory else {}, "merchants": trade.snapshot() if trade else {}, "schedule":schedule.snapshot() if schedule else {},"routines":routines.snapshot() if routines else {},"dog":dog.snapshot() if dog else {}}

func world_input_blocked(ignore_inventory := false) -> bool:
	if bath_service and bath_service.panel.is_open(): return true
	if inventory and is_instance_valid(inventory.reading_dialog) and inventory.reading_dialog.visible: return true
	if map_viewer and map_viewer.is_open(): return true
	if not ignore_inventory and fullscreen_ui and fullscreen_ui.bag_open and fullscreen_ui.inventory_paper and fullscreen_ui.inventory_paper.visible: return true
	if looting and looting.is_open(): return true
	if tutorial and tutorial.blocks_input(): return true
	return phase != "playing" or get_tree().paused or (fullscreen_ui != null and fullscreen_ui.menu.visible) or (shop_panel != null and shop_panel.panel.visible) or (schedule != null and schedule.panel.visible) or (developer_settings != null and developer_settings.panel.visible) or (dialogue != null and dialogue.panel.visible)

func finish_timeout() -> void:
	finish_failure("逃脱期限已到 · 时间耗尽")

func finish_failure(reason: String) -> void:
	if phase != "playing": return
	if dialogue: dialogue.close()
	if looting: looting.close()
	failure_reason = reason
	phase = "failed"
	orders.clear()
	skills.clear_all()
	for actor in actors:
		actor.moved_this_frame = false
	guard.moved_this_frame = false
	dog.moved_this_frame = false
	status_text = reason+"，行动结束。可重新开始。"
	schedule.show_result(false)

func capture_actor(actor_id: int) -> void:
	if actor_id==PLAYER_ACTOR_ID and looting: looting.close()
	if actor_id==PLAYER_ACTOR_ID:
		if map_viewer: map_viewer.close()
		if fullscreen_ui:
			fullscreen_ui.bag_open = false
			fullscreen_ui.refresh_inventory()
	if tutorial and tutorial.active:
		tutorial.on_capture(actor_id)
		return
	if phase != "playing" or actor_id < 0 or actor_id >= actors.size() or actors[actor_id].escaped or actors[actor_id].confined: return
	if dialogue: dialogue.close()
	if mobile_controls and selected_actor_id == actor_id:
		mobile_controls.cancel_input()
	if routines:
		routines.suspend(actor_id)
	if shop_panel and shop_panel.actor_id == actor_id:
		shop_panel.close()
	var actor = actors[actor_id]
	if social and actor_id==PLAYER_ACTOR_ID: social.player_captured(actor.position)
	if skills:
		skills.cancel(actor_id)
	actor.position = actor.home
	if room_access:
		room_access.capture(actor_id)
	actor.action_state = "idle"
	actor.immune_until = elapsed + 1.0
	actor.queue_redraw()
	orders.stop(actor_id)
	captures += 1
	if room_access and room_access.is_held(actor_id):
		confinement_counts[actor_id] += 1
		if actor_id == PLAYER_ACTOR_ID and confinement_counts[actor_id] >= 3:
			finish_failure("主角第三次被关禁闭 · 逃脱失败")
	if room_access == null or not room_access.is_held(actor_id):
		show_status("伙伴%d被送回起点；门、箱子、技能和已逃脱伙伴保留。" % (actor_id+1))

func show_status(text: String, duration: float = 2.5) -> void:
	status_text = social.localize(text) if social else text
	status_until = elapsed + duration

func use_selected_skill() -> void:
	if not actor_is_controllable(selected_actor_id): return
	if mobile_controls:
		mobile_controls.cancel_input()
	if skills and skills.actions.has(selected_actor_id):
		skills.cancel(selected_actor_id, "已停止操作，撬锁进度保留。")
		return
	if actors[selected_actor_id].skill_id == "backpack":
		show_status("会收纳是被动能力：背包30格，无需使用技能。")
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
	if dialogue and dialogue.current_target.get("role","") in ["patrol","gate","overseer","reinforcement"]: dialogue.close()
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
	preload("res://scripts/presentation/world_texture.gd").release_scene_cache()
	preload("res://scripts/presentation/character_library.gd").prepared_motions.clear()
	preload("res://scripts/presentation/region_terrain.gd").textures.clear()
	preload("res://scripts/presentation/region_terrain.gd").definitions.clear()
	world.art_textures.clear()
	world.configure(config,actors)
	for index in range(actors.size()):
		var start: Array = config.starts[index]
		actors[index].home = Vector2(start[0],start[1])
	guard.configure(world,self)
	if room_selector:
		var selector_index := ROOM_IDS.find(identifier)
		if selector_index >= 0:
			room_selector.select(selector_index)
	reset_round(fixed_skills,seed_value)
	return true
