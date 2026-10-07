extends Node

var game
var config: Dictionary
var panel: Panel
var speaker: Label
var body: Label
var note: Label
var casual_button: Button
var rules_button: Button
var special_button: Button
var end_button: Button
var current_target: Dictionary = {}
var line_index := 0
var last_size := Vector2.ZERO

func configure(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	panel = Panel.new()
	panel.name = "NpcConversation"
	panel.z_index = 100
	panel.theme = game.fullscreen_ui.theme
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("7d8b7e")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel",paper)
	game.get_node("HUD").add_child(panel)
	speaker = make_label(20)
	body = make_label(17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note = make_label(12)
	note.text = "交谈时钟继续 · 劳动与看守照常行动"
	note.add_theme_color_override("font_color",Color("727d70"))
	casual_button = make_button("聊两句",casual)
	rules_button = make_button("问作息",rules)
	special_button = make_button("问近况",special)
	end_button = make_button("×",close)
	end_button.tooltip_text = "结束聊天，继续行动（Esc）"
	panel.hide()
	layout()

func make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	panel.add_child(button)
	return button

func targets() -> Array:
	var result: Array = []
	for id in range(game.actors.size()):
		if id == game.PLAYER_ACTOR_ID: continue
		result.append({"id":"prisoner:%d" % id,"name":"囚徒%d" % (id+1),"role":"prisoner","node":game.actors[id]})
	result.append({"id":"guard:patrol","name":"巡逻看守","role":"patrol","node":game.guard})
	if game.gate_watch:
		for guard in game.gate_watch.guards:
			result.append({"id":"guard:"+guard.guard_id,"name":"门岗看守","role":"gate","node":guard})
	if game.workshop and is_instance_valid(game.workshop.overseer):
		result.append({"id":"guard:overseer","name":"监工","role":"overseer","node":game.workshop.overseer})
	if game.prison_alert:
		for guard in game.prison_alert.reinforcements:
			result.append({"id":"guard:reinforcement:%d" % guard.get_instance_id(),"name":"搜查看守","role":"reinforcement","node":guard})
	if game.trade:
		for id in game.trade.actors:
			result.append({"id":"merchant:"+str(id),"name":str(game.trade.merchants[id].name),"role":"merchant","node":game.trade.actors[id]})
	return result.filter(func(t): return is_instance_valid(t.node) and t.node.visible and not t.node.escaped)

func find_target(id: String) -> Dictionary:
	for target in targets():
		if target.id == id: return target
	return {}

func reason(id: String) -> String:
	return reason_target(find_target(id))

func reason_target(target: Dictionary) -> String:
	if game.phase != "playing" or not game.actor_is_controllable(game.selected_actor_id): return "当前不能交谈。"
	var actor = game.actors[game.selected_actor_id]
	if actor.confined: return "禁闭中，出门后再找人交谈。"
	if target.is_empty() or not is_instance_valid(target.get("node")): return "对方已离开。"
	if target.role == "prisoner" and game.schedule.is_sleeping(target.node.actor_id): return "对方正在睡觉。"
	if actor.position.distance_to(target.node.position) > float(config.range): return "靠近对方再聊天。"
	if not game.world.line_clear(actor.position,target.node.position): return "你们之间有墙或锁门遮挡。"
	return ""

func open(id: String) -> bool:
	if game.world_input_blocked(): return false
	var error := reason(id)
	if not error.is_empty():
		game.show_status(error)
		return false
	close()
	current_target = find_target(id)
	var actor = game.actors[game.selected_actor_id]
	game.mobile_controls.cancel_input()
	game.orders.stop(actor.actor_id)
	game.skills.cancel(actor.actor_id)
	game.routines.take_control(actor.actor_id)
	actor.action_state = "chatting"
	actor.facing = actor.position.direction_to(current_target.node.position)
	line_index = 0
	speaker.text = current_target.name+" · 交谈"
	var guard: bool = current_target.role in ["patrol","gate","overseer","reinforcement"]
	special_button.text = "分散注意" if guard else "购买" if current_target.role == "merchant" else "问近况"
	special_button.tooltip_text = "只有会聊天技能可以使看守分心；普通交谈不影响巡逻与抓捕。" if guard else ""
	panel.show()
	layout()
	casual()
	tick()
	game._update_ui()
	return true

func casual() -> void:
	if current_target.is_empty(): return
	var lines: Array = config.roles[current_target.role].greeting
	body.text = str(lines[line_index%lines.size()])
	line_index += 1

func rules() -> void:
	if current_target.is_empty(): return
	body.text = str(config.roles[current_target.role].rules)

func special() -> void:
	if current_target.is_empty(): return
	if current_target.role in ["patrol","gate","overseer","reinforcement"]:
		var target = current_target.node
		var error: String = game.skills.chat_reason(game.actors[game.selected_actor_id],target)
		if game.actors[game.selected_actor_id].skill_id != "chat": error = "需要“会聊天”技能；普通聊天不会让看守放弃值守。"
		if not error.is_empty():
			body.text = error
			return
		close()
		game.skills.start_chat_with(game.selected_actor_id,target)
		game._update_ui()
	elif current_target.role == "merchant":
		var id: String = str(current_target.id).trim_prefix("merchant:")
		var error: String = game.trade.reason(game.selected_actor_id,id)
		if not error.is_empty():
			body.text = error
			return
		close()
		game.shop_panel.open(id)
	else:
		body.text = str(config.roles[current_target.role].daily).replace("{activity}",game.routines.status_for(current_target.node.actor_id))

func holds_movement(actor) -> bool:
	return panel.visible and current_target.get("role","") in ["prisoner","merchant"] and is_instance_valid(current_target.get("node")) and current_target.node == actor

func close() -> void:
	if panel: panel.hide()
	if game and not current_target.is_empty():
		var actor = game.actors[game.PLAYER_ACTOR_ID]
		if actor.action_state == "chatting" and not game.skills.actions.has(actor.actor_id): actor.action_state = "idle"
	current_target.clear()

func tick() -> void:
	if not panel.visible: return
	if game.phase != "playing" or game.get_tree().paused or game.routine_panel.panel.visible or game.fullscreen_ui.menu.visible or game.shop_panel.panel.visible:
		close()
		return
	var next := find_target(str(current_target.get("id","")))
	var error := reason_target(next)
	if not error.is_empty():
		close()
		game.show_status(error)
		return
	current_target = next
	var guard: bool = current_target.role in ["patrol","gate","overseer","reinforcement"]
	special_button.disabled = guard and (game.actors[0].skill_id != "chat" or not game.skills.chat_reason(game.actors[0],current_target.node).is_empty())
	if current_target.role == "merchant":
		var id: String = str(current_target.id).trim_prefix("merchant:")
		special_button.disabled = not game.trade.reason(0,id).is_empty()
		special_button.tooltip_text = game.trade.reason(0,id)

func layout() -> void:
	if not panel: return
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	var left: float = game.cards[0].position.x+game.cards[0].size.x+16
	var right: float = game.fullscreen_ui.target_button.position.x-12
	var width: float = minf(640,maxf(300,right-left))
	panel.size = Vector2(width,210)
	panel.position = Vector2(clampf(safe.get_center().x-width/2,left,maxf(left,right-width)),safe.end.y-210)
	speaker.position = Vector2(18,14)
	speaker.size = Vector2(width-72,30)
	end_button.position = Vector2(width-46,10)
	end_button.size = Vector2(32,32)
	body.position = Vector2(18,54)
	body.size = Vector2(width-36,73)
	note.position = Vector2(18,134)
	var buttons: Array = [casual_button,rules_button,special_button]
	var button_width: float = (width-48)/3
	for index in range(3):
		buttons[index].position = Vector2(18+index*(button_width+6),161)
		buttons[index].size = Vector2(button_width,36)
	last_size = game.get_viewport_rect().size

func _process(_delta: float) -> void:
	if game and last_size != game.get_viewport_rect().size: layout()

func snapshot() -> Dictionary:
	return {"visible":panel.visible,"target_id":current_target.get("id",""),"role":current_target.get("role",""),"speaker":speaker.text,"text":body.text}
