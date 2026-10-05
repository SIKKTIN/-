extends Node

var game
var presentation
var button: Button
var actor_id: int = -1
var kind: String = ""
var extras: Dictionary = {}
var targets: Array = []

func configure(owner_game, owner_presentation) -> void:
	game = owner_game
	presentation = owner_presentation
	button = Button.new()
	button.name = "WorldInteraction"
	button.size = Vector2(64,48)
	button.theme = presentation.mute_button.theme
	button.text = "E"
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_constant_override("icon_max_width",25)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(activate)
	game.get_node("HUD").add_child(button)
	refresh()

func refresh() -> void:
	_refresh_targets()
	# Keep valid buttons visible across frames so a held touch can release normally.
	if not targets.any(func(t): return t.button == button):
		button.visible = false
	for b in extras.values():
		if not targets.any(func(t): return t.button == b):
			b.visible = false

func _refresh_targets() -> void:
	kind = ""
	targets.clear()
	actor_id = game.selected_actor_id
	if game.world_input_blocked():
		return
	var actor = game.actors[actor_id]
	if actor.escaped:
		return
	_refresh_items(actor)
	var anchor := Vector2.ZERO
	var active: bool = game.skills.actions.has(actor_id)
	if active:
		kind = str(game.skills.actions[actor_id].kind)
		anchor = game.guard.position+Vector2(40,-80) if kind == "chat" else game.world.door.get_center()+Vector2(36,-55)
		button.tooltip_text = "停止操作（E）；撬锁进度保留。"
	elif actor.skill_id == "strong":
		var box: Rect2 = game.world.crate
		if actor.position.distance_to(actor.position.clamp(box.position,box.end)) > 35:
			return
		kind = "strong"
		anchor = box.get_center()+Vector2(0,-box.size.y/2-42)
		button.tooltip_text = "推箱：点击或E，向远离当前伙伴的方向推；S停止。"
	elif game.skills.target_reason(actor) == "":
		kind = actor.skill_id
		anchor = game.guard.position+Vector2(40,-80) if kind == "chat" else game.world.door.get_center()+Vector2(36,-55)
		button.tooltip_text = "停止操作（E）；撬锁进度保留。" if active else "交谈（E）" if kind == "chat" else "撬锁（E）"
	else:
		return
	button.icon = presentation.skill_icons.get("lockpick" if kind == "lock_tool" else kind)
	button.text = "停" if active else "E"
	var screen: Vector2 = game.get_global_transform_with_canvas()*anchor
	_place(button, screen)
	targets.append({"button": button, "kind": "skill", "id": "", "distance": -1.0 if active else actor.position.distance_to(game.guard.position if kind == "chat" else game.world.door.get_center())})

func _extra(key: String, text: String, anchor: Vector2, tooltip: String) -> Button:
	if not extras.has(key):
		var b := Button.new()
		b.name = "Interact_"+key
		b.size = Vector2(84, 48)
		b.theme = button.theme
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_activate_extra.bind(key))
		game.get_node("HUD").add_child(b)
		extras[key] = b
	var b: Button = extras[key]
	b.text = text
	if game.items_view:
		var icon_id := "trade" if key.begins_with("trade:") else "full" if game.inventory.items(game.selected_actor_id).size() >= game.inventory.capacity(game.selected_actor_id) else "pickup"
		b.icon = game.items_view.icon_for(icon_id)
		b.add_theme_constant_override("icon_max_width",20)
		b.expand_icon = true
		if icon_id == "full":
			b.text = "满包"
	b.tooltip_text = tooltip
	_place(b, game.get_global_transform_with_canvas()*anchor)
	return b

func _place(b: Button, screen: Vector2) -> void:
	var view: Rect2 = game.map_camera.view_rect() if game.map_camera else Rect2(Vector2.ZERO,game.get_viewport_rect().size)
	b.visible = view.has_point(screen)
	b.position = (screen-b.size/2).clamp(view.position+Vector2(3,3),view.end-b.size-Vector2(3,3))

func _refresh_items(actor) -> void:
	if not game.inventory or not game.trade:
		return
	for id in game.inventory.instances:
		var entry: Dictionary = game.inventory.instances[id]
		if entry.location != "ground":
			continue
		var point := Vector2(entry.position[0], entry.position[1])
		if actor.position.distance_to(point) > 60 or not game.world.line_clear(actor.position, point):
			continue
		var b := _extra("pickup:"+id, "拾取", point+Vector2(0,-48), "拾取（E）；满包时不会覆盖。")
		targets.append({"button": b, "kind": "pickup", "id": id, "distance": actor.position.distance_to(point)})
	for id in game.trade.merchants:
		if game.trade.reason(actor.actor_id, id) != "":
			continue
		var pos: Array = game.trade.merchants[id].position
		var point := Vector2(pos[0], pos[1])
		var b := _extra("trade:"+id, "交易", point+Vector2(0,-86), "商人营业中（12–14 / 18–20）；买卖（E），时间继续运行。")
		targets.append({"button": b, "kind": "trade", "id": id, "distance": actor.position.distance_to(point)})
	for key in extras.keys():
		if key.begins_with("pickup:") and not game.inventory.instances.has(key.substr(7)):
			extras[key].queue_free()
			extras.erase(key)

func _activate_extra(key: String) -> void:
	if game.world_input_blocked():
		return
	if key.begins_with("pickup:"):
		var result: Dictionary = game.inventory.try_pickup(game.selected_actor_id, key.substr(7))
		game.show_status(str(result.reason) if str(result.reason) != "" else "物品已放入当前伙伴背包。")
	else:
		game.shop_panel.open(key.substr(6))
	game._update_ui()
	refresh()

func activate_nearest() -> void:
	refresh()
	if targets.is_empty():
		game.show_status("靠近目标后点击互动图标，或选背包物品使用。")
		return
	targets = targets.filter(func(t): return t.button.visible)
	if targets.is_empty():
		return
	targets.sort_custom(func(a, b): return a.distance < b.distance)
	var target: Dictionary = targets[0]
	for entry in targets:
		if entry.button.get_global_rect().has_point(entry.button.get_global_mouse_position()):
			target = entry
			break
	if target.kind == "skill":
		activate(false)
	else:
		_activate_extra(str(target.kind)+":"+str(target.id))

func activate(check_selection: bool = true) -> void:
	var previous_id := actor_id
	refresh()
	if not button.visible or (check_selection and previous_id != game.selected_actor_id):
		return
	if kind == "strong":
		var actor = game.actors[actor_id]
		var box: Rect2 = game.world.crate
		var delta: Vector2 = box.get_center()-actor.position
		var direction := Vector2(signf(delta.x),0) if absf(delta.x) > absf(delta.y) else Vector2(0,signf(delta.y))
		if direction == Vector2.ZERO:
			return
		var goal: Vector2 = (actor.position+direction*65).clamp(game.world.bounds.position+Vector2(17,17),game.world.bounds.end-Vector2(17,17))
		game.command_move(actor_id,goal)
	else:
		game.use_selected_skill()
	refresh()

func snapshot() -> Dictionary:
	return {"visible":button.visible,"actor_id":actor_id,"kind":kind,"position":[button.position.x,button.position.y]}
