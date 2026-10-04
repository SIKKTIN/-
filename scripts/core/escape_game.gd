extends Node2D

const Prisoner = preload("res://scripts/actors/prisoner.gd")
const World = preload("res://scripts/world/prison_world.gd")
const Guard = preload("res://scripts/actors/guard.gd")
const Skills = preload("res://scripts/skills/skill_controller.gd")
const Presentation = preload("res://scripts/presentation/game_presentation.gd")
const MoveOrders = preload("res://scripts/core/move_orders.gd")
const TextureTiles = preload("res://scripts/presentation/texture_tiles.gd")
const ROOM := Rect2(74, 114, 922, 560)
const STARTS := [Vector2(180, 235), Vector2(235, 375), Vector2(185, 510)]
const ACTOR_RADIUS := 17.0
const MOVE_SPEED := 260.0
const SKILL_NAMES := {"chat": "会聊天", "lockpick": "会撬锁", "strong": "大力气"}

var actors: Array = []
var selected_actor_id: int = 0
var orders
var status_text: String = "左键选人，右键地面移动；E使用技能，S停止。"
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
	world.configure(config,actors)
	for index in range(actors.size()):
		var start: Array = config.starts[index]
		actors[index].home = Vector2(start[0],start[1])
	guard = Guard.new()
	guard.name = "Guard"
	add_child(guard)
	guard.configure(world,self)
	skills = Skills.new(self)
	orders = MoveOrders.new(self)
	_build_ui()
	reset_round()
	presentation = Presentation.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.configure(self)

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
	subtitle.text = "随机技能 · 独立行动 · 留下伙伴操作，再切换其他人"
	subtitle.position = Vector2(34, 70)
	subtitle.add_theme_color_override("font_color", Color("536052"))
	layer.add_child(subtitle)
	room_selector = OptionButton.new()
	room_selector.name = "RoomSelector"
	room_selector.position = Vector2(566,35)
	room_selector.size = Vector2(230,42)
	room_selector.add_item("R01 · 双通路")
	room_selector.add_item("R02 · 门边掩护")
	room_selector.set_item_disabled(1,not FileAccess.file_exists("res://data/rooms/r02.json"))
	room_selector.select(0 if room_id == "r01" else 1)
	room_selector.item_selected.connect(func(index): load_room("r01" if index == 0 else "r02"))
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
		if presentation:
			presentation.tick(delta)
		return
	elapsed += delta
	for actor in actors:
		actor.moved_this_frame = false
	orders.tick(delta)
	skills.tick(delta)
	guard.tick(delta)
	guard_position = guard.position
	if phase == "playing" and elapsed >= status_until:
		status_text = "逃脱 %d / 3 · 锁门%s · 抓回 %d 次 · 狱警%s" % [actors.filter(func(a): return a.escaped).size(),"已开" if world.door_open else "%d%%"%roundi(world.lock_progress*100),captures,"追击中" if guard.state == "chasing" else ("交谈中" if guard.state == "talking" else "巡逻中")]
	_update_ui()
	if presentation:
		presentation.tick(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_at(point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if world.exit_area.has_point(point) or Rect2(927,410,54,54).has_point(point):
				point = Vector2(maxf(point.x,world.bounds.end.x+ACTOR_RADIUS+4),clampf(point.y,world.exit_area.position.y+ACTOR_RADIUS+1,world.exit_area.end.y-ACTOR_RADIUS-1))
			command_move(selected_actor_id,point)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			select_actor(event.keycode - KEY_1)
		elif event.keycode == KEY_R:
			reset_round()
		elif event.keycode == KEY_E:
			use_selected_skill()
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

func stop_selected() -> void:
	orders.stop(selected_actor_id)
	skills.cancel(selected_actor_id,"当前伙伴已停止操作，撬锁进度保留。")
	show_status("伙伴%d已停止。" % (selected_actor_id+1))
	_update_ui()

func on_actor_escaped(actor_id: int) -> void:
	if selected_actor_id == actor_id:
		for other in actors:
			if not other.escaped:
				select_actor(other.actor_id)
				break
	if actors.all(func(a): return a.escaped):
		phase = "complete"
		orders.clear()
		skills.clear_all()
		status_text = "三人全部逃脱！用时%.1f秒 · 抓回%d次 · R重新开始" % [elapsed,captures]

func select_actor(index: int) -> void:
	if index < 0 or index >= actors.size() or actors[index].escaped:
		return
	selected_actor_id = index
	for actor in actors:
		actor.selected = actor.actor_id == index
		actor.queue_redraw()
	_update_ui()

func reset_round(fixed_skills: Array = [], seed_value: int = -1) -> void:
	phase = "playing"
	elapsed = 0
	status_until = 0
	captures = 0
	deal_number += 1
	deal_seed = randi() if seed_value < 0 else seed_value
	var random := RandomNumberGenerator.new()
	random.seed = deal_seed
	var choices := ["chat","lockpick","strong"]
	if skills:
		skills.clear_all()
	if orders:
		orders.clear()
	for actor in actors:
		actor.reset_actor()
		actor.skill_id = str(fixed_skills[actor.actor_id]) if fixed_skills.size() == 3 else choices[random.randi_range(0,2)]
	if world:
		world.reset_world()
	if guard:
		guard.reset_guard()
		guard_position = guard.position
	if presentation:
		presentation.reset()
	show_status("本局随机技能允许重复；目标是三人全部逃脱。")
	select_actor(0)
	_update_ui()
	queue_redraw()

func _update_ui() -> void:
	if cards.is_empty():
		return
	for index in range(actors.size()):
		var actor = actors[index]
		var action_labels := {"idle":"待命","chatting":"交谈中","lockpicking":"撬锁中"}
		cards[index].text = "%s伙伴 %d\n%s\n%s" % ["● " if actor.selected else "", index + 1, SKILL_NAMES[actor.skill_id], "已逃脱" if actor.escaped else ("移动中" if orders and orders.active.has(index) else action_labels.get(actor.action_state,"待命"))]
		cards[index].disabled = actor.escaped
	status_label.text = status_text
	if skill_button and skills:
		var actor = actors[selected_actor_id]
		var active: bool = skills.actions.has(selected_actor_id)
		var reason: String = skills.target_reason(actor)
		skill_button.text = "停止技能  E" if active else ("接触重箱自动推" if actor.skill_id == "strong" else "使用%s  E" % SKILL_NAMES[actor.skill_id])
		skill_button.disabled = phase != "playing" or actor.escaped or actor.skill_id == "strong" or (not active and reason != "")
		var no_opener: bool = actors.all(func(a): return a.skill_id == "chat")
		hint_label.text = "全聊天：缺少开路技能，可按R重抽。" if no_opener else ("伙伴留在原地操作，可以换人行动。" if active else (reason if reason != "" else skills.library[actor.skill_id].description))

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("f2ebdd"))
	draw_style_box(_floor_style(), ROOM)
	if floor_texture:
		TextureTiles.paint(self,floor_texture,Rect2(75,115,920,558),Vector2(floor_tile_size,floor_tile_size),ROOM)
	if not perspective_floor:
		for x in range(94, 995, 40):
			draw_line(Vector2(x, 115), Vector2(x, 673), Color(0.2, 0.3, 0.25, 0.04))
		for y in range(134, 674, 40):
			draw_line(Vector2(75, y), Vector2(995, y), Color(0.2, 0.3, 0.25, 0.04))
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
	return {"phase": phase, "elapsed": elapsed, "selected_actor_id": selected_actor_id, "orders":orders.snapshot() if orders else [], "actors": actors.map(func(actor): return actor.snapshot()), "guard_position": [guard_position.x, guard_position.y],"guard":guard.snapshot() if guard else {},"world":world.snapshot() if world else {},"captures":captures,"seed":deal_seed,"deal":deal_number,"actions":skills.snapshot() if skills else []}

func capture_actor(actor_id: int) -> void:
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
	if skills and phase == "playing":
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
	room_id = identifier
	world.configure(config,actors)
	for index in range(actors.size()):
		var start: Array = config.starts[index]
		actors[index].home = Vector2(start[0],start[1])
	guard.configure(world,self)
	if room_selector:
		room_selector.select(0 if identifier == "r01" else 1)
	reset_round(fixed_skills,seed_value)
	return true
