extends Node

var game
var presentation
var button: Button
var actor_id: int = -1
var kind: String = ""

func configure(owner_game, owner_presentation) -> void:
	game = owner_game
	presentation = owner_presentation
	button = Button.new()
	button.name = "WorldInteraction"
	button.size = Vector2(52,46)
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
	button.visible = false
	kind = ""
	actor_id = game.selected_actor_id
	if game.phase != "playing" or game.get_tree().paused:
		return
	var actor = game.actors[actor_id]
	if actor.escaped:
		return
	var anchor := Vector2.ZERO
	var active: bool = game.skills.actions.has(actor_id)
	if actor.skill_id == "strong":
		var box: Rect2 = game.world.crate
		if actor.position.distance_to(actor.position.clamp(box.position,box.end)) > 35:
			return
		kind = "strong"
		anchor = box.get_center()+Vector2(0,-box.size.y/2-42)
		button.tooltip_text = "推箱：点击或E，向远离当前伙伴的方向推；S停止。"
	elif active or game.skills.target_reason(actor) == "":
		kind = actor.skill_id
		anchor = game.guard.position+Vector2(40,-80) if kind == "chat" else game.world.door.get_center()+Vector2(36,-55)
		button.tooltip_text = "停止操作（E）；撬锁进度保留。" if active else "交谈（E）" if kind == "chat" else "撬锁（E）"
	else:
		return
	button.icon = presentation.skill_icons[kind]
	button.text = "停" if active else "E"
	var screen: Vector2 = game.get_global_transform_with_canvas()*anchor
	button.position = (screen-button.size/2).clamp(Vector2(77,117),Vector2(941,625))
	button.visible = true

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
