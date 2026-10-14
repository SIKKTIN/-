extends Node2D

const Session = preload("res://scripts/core/game_session.gd")
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
var keycards
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
var nine_point
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
	if nine_point and nine_point.is_open(): return
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
	Session.on_actor_escaped(self,actor_id)

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
	Session.reset_round(self,fixed_skills,seed_value)

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
	if nine_point and nine_point.is_open(): return true
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
	Session.finish_failure(self,reason)

func capture_actor(actor_id: int) -> void:
	Session.capture_actor(self,actor_id)

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
	return Session.load_room(self,identifier,fixed_skills,seed_value)
