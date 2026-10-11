extends Node

var game
var config: Dictionary
var panel: Panel
var speaker: Label
var body: Label
var responses: Control
var casual_button: Button
var rules_button: Button
var special_button: Button
var end_button: Button
var current_target: Dictionary = {}
var line_index := 0
var last_size := Vector2.ZERO
var text_layout_key: Array = []
var anchor_key: Array = []
var response_layout_key: Array = []
var last_choice := 0
var social_note: Label

func configure(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	panel = preload("res://scripts/ui/npc_speech_panel.gd").new()
	panel.name = "NpcConversation"
	panel.z_index = 151
	panel.theme = game.fullscreen_ui.theme
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("68796c")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(8)
	paper.shadow_color = Color(0,0,0,0.15)
	paper.shadow_size = 4
	panel.add_theme_stylebox_override("panel",paper)
	game.get_node("HUD").add_child(panel)
	speaker = make_label(16)
	body = make_label(17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	social_note = make_label(12)
	social_note.add_theme_color_override("font_color",Color("667e70"))
	social_note.clip_text = true
	responses = preload("res://scripts/ui/npc_response_choices.gd").new()
	game.get_node("HUD").add_child(responses)
	responses.configure(game.fullscreen_ui)
	casual_button = make_response("先聊两句吧。",casual)
	rules_button = make_response("这里每天怎么安排？",rules)
	special_button = make_response("你最近怎么样？",special)
	end_button = make_button("×",close)
	end_button.tooltip_text = "结束聊天，继续行动（Esc）"
	panel.hide()
	layout()

func make_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_font_override("font",game.presentation.font)
	label.add_theme_color_override("font_color",Color("303b46"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",14)
	var base := StyleBoxFlat.new()
	base.bg_color = Color("ebe5d6")
	base.border_color = Color("8d998b")
	base.set_border_width_all(1)
	base.set_corner_radius_all(6)
	var hover := base.duplicate()
	hover.bg_color = Color("e0e8de")
	hover.border_color = Color("328d84")
	var pressed := hover.duplicate()
	pressed.bg_color = Color("ccdcd2")
	var disabled := base.duplicate()
	disabled.bg_color = Color("eee9dd")
	disabled.border_color = Color("c7c9bb")
	button.add_theme_stylebox_override("normal",base)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("disabled",disabled)
	button.pressed.connect(callback)
	panel.add_child(button)
	return button

func make_response(text: String, callback: Callable) -> Button:
	var button = preload("res://scripts/ui/npc_response_choice.gd").new()
	responses.add_child(button)
	button.configure(game.presentation.font,text,callback)
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
	if game.social:
		for target in result:
			var p: Dictionary = game.social.person(str(target.id))
			if not p.is_empty(): target.name = p.name+" · "+p.role_name
	return result.filter(func(t): return is_instance_valid(t.node) and t.node.visible and not t.node.escaped and not game.world.is_under_roof(t.node.position))

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
	if game.world.is_under_roof(target.node.position): return "对方在不可见的房间内，进入后再交谈。"
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
	last_choice = 0
	speaker.text = current_target.name
	var guard: bool = current_target.role in ["patrol","gate","overseer","reinforcement"]
	special_button.text = "帮我分散一下注意。" if guard else "我想买些东西。" if current_target.role == "merchant" else "你能帮我一下吗？"
	special_button.tooltip_text = "只有会聊天技能可以使看守分心；普通交谈不影响巡逻与抓捕。" if guard else ""
	panel.show()
	responses.show()
	refresh_choices()
	layout()
	casual(false)
	tick()
	game._update_ui()
	return true

func casual(clicked := true) -> void:
	if current_target.is_empty(): return
	last_choice = 0
	var lines: Array = config.roles[current_target.role].greeting
	body.text = str(lines[line_index%lines.size()])
	if game.social: body.text = game.social.chat(str(current_target.id),clicked)
	line_index += 1
	refresh_choices()
	layout()

func rules() -> void:
	if current_target.is_empty(): return
	last_choice = 1
	body.text = str(config.roles[current_target.role].rules)
	if game.social and game.social.knowledge.get("workshop_warning",{}).get("source","")==str(current_target.id):
		body.text = str(game.social.knowledge.workshop_warning.text)
	if game.social: body.text = game.social.answer(str(current_target.id),body.text)
	refresh_choices()
	layout()

func special() -> void:
	if current_target.is_empty(): return
	last_choice = 2
	if current_target.role in ["patrol","gate","overseer","reinforcement"]:
		var target = current_target.node
		var error: String = game.skills.chat_reason(game.actors[game.selected_actor_id],target)
		if game.actors[game.selected_actor_id].skill_id != "chat": error = "需要“会聊天”技能；普通聊天不会让看守放弃值守。"
		if not error.is_empty():
			body.text = error
			layout()
			return
		close()
		game.skills.start_chat_with(game.selected_actor_id,target)
		game._update_ui()
	elif current_target.role == "merchant":
		var id: String = str(current_target.id).trim_prefix("merchant:")
		var error: String = game.trade.reason(game.selected_actor_id,id)
		if not error.is_empty():
			body.text = error
			layout()
			return
		close()
		game.shop_panel.open(id)
	else:
		body.text = game.social.request_help(str(current_target.id)) if game.social else str(config.roles[current_target.role].daily).replace("{activity}",game.routines.status_for(current_target.node.actor_id))
		refresh_choices()
		layout()

func holds_movement(actor) -> bool:
	return panel.visible and current_target.get("role","") in ["prisoner","merchant"] and is_instance_valid(current_target.get("node")) and current_target.node == actor

func close() -> void:
	if panel: panel.hide()
	if responses: responses.hide()
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
	refresh_choices()

func refresh_choices() -> void:
	if current_target.is_empty(): return
	if game.social:
		social_note.text = game.social.summary(str(current_target.id))
		var p: Dictionary = game.social.person(str(current_target.id))
		panel.tooltip_text = p.traits.trait_label+" · "+p.traits.history
		casual_button.text = "给你2块钱，谢谢你。" if p.debt>0 and game.inventory.wallet>=2 else "先聊两句吧。"
		rules_button.text = "再说说你上次的消息。" if game.social.knowledge.get("workshop_warning",{}).get("source","")==str(current_target.id) else "这里每天怎么安排？"
	var reason := ""
	if current_target.role in ["patrol","gate","overseer","reinforcement"]:
		reason = "需要「会聊天」能力" if game.actors[0].skill_id!="chat" else game.skills.chat_reason(game.actors[0],current_target.node)
	if current_target.role == "merchant":
		var id: String = str(current_target.id).trim_prefix("merchant:")
		reason = game.trade.reason(0,id)
	for index in range(3):
		var button = [casual_button,rules_button,special_button][index]
		button.set_state(index==2 and not reason.is_empty(),reason if index==2 else "",last_choice==index)
	special_button.tooltip_text = reason if not reason.is_empty() else "只有会聊天能力可以使看守分心；普通交谈不影响巡逻与抓捕。" if current_target.role in ["patrol","gate","overseer","reinforcement"] else ""
	layout_responses()
	position_speech()

func layout_responses() -> void:
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	var compact: bool = game.get_viewport_rect().size.y<620
	var width := minf(408,safe.size.x-36)
	var key := [safe,compact,width,special_button.requirement.visible]
	if key==response_layout_key: return
	response_layout_key = key
	responses.compact = compact
	var y := 46.0 if compact else 54.0
	var buttons := [casual_button,rules_button,special_button]
	for button in buttons:
		button.add_theme_font_size_override("font_size",18 if compact else 20)
		var height := 44.0 if compact else 48.0
		if button.requirement.visible: height = 62.0 if compact else 64.0
		button.position = Vector2(0,y)
		button.size = Vector2(width,height)
		y += height+(8 if compact else 10)
	responses.size = Vector2(width,y-(8 if compact else 10))
	responses.position = Vector2(safe.get_center().x-width/2,safe.end.y-responses.size.y)
	responses.queue_redraw()
	anchor_key.clear()

func layout() -> void:
	if not panel: return
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	var width := minf(350 if game.get_viewport_rect().size.y<620 else 384,safe.size.x-36)
	var key := [body.text,width]
	if key!=text_layout_key:
		text_layout_key = key
		body.size = Vector2(width-28,0)
		var text_height := maxf(27,ceilf(body.get_minimum_size().y))
		social_note.visible = game.social!=null and not (game.get_viewport_rect().size.y<620 and text_height>80)
		body.position = Vector2(14,64 if social_note.visible else 42)
		panel.size = Vector2(width,text_height+80 if social_note.visible else text_height+58)
		social_note.position = Vector2(14,39)
		social_note.size = Vector2(width-28,20)
		speaker.position = Vector2(26,9)
		speaker.size = Vector2(width-70,25)
		end_button.position = Vector2(width-37,7)
		end_button.size = Vector2(30,28)
		body.size = Vector2(width-28,text_height)
		anchor_key.clear()
	last_size = game.get_viewport_rect().size
	layout_responses()
	position_speech()

func position_speech() -> void:
	if not panel.visible or not is_instance_valid(current_target.get("node")): return
	var transform: Transform2D = game.get_global_transform_with_canvas()
	var mouth: Vector2 = transform*current_target.node.position+Vector2(0,-48)
	var player_foot: Vector2 = transform*game.actors[0].position
	var safe: Rect2 = game.fullscreen_ui.safe_area()
	var next_key := [mouth,player_foot,safe,panel.size,responses.get_global_rect(),game.mini_map.visible]
	if next_key==anchor_key: return
	anchor_key = next_key
	var low := safe.position+Vector2(18,128)
	var high := (safe.end-panel.size-Vector2(18,18)).max(low)
	var bodies := [Rect2(player_foot-Vector2(22,64),Vector2(44,64)),Rect2(mouth-Vector2(22,16),Vector2(44,64)),game.mobile_controls.pad.get_global_rect()]
	if responses.visible: bodies.append(responses.get_global_rect().grow(8))
	if game.mini_map.visible: bodies.append(game.mini_map.get_global_rect())
	var candidates := [mouth-Vector2(panel.size.x/2,panel.size.y+22),mouth+Vector2(42,-92),mouth-Vector2(panel.size.x+42,92),mouth+Vector2(-panel.size.x/2,70)]
	candidates.append(Vector2(low.x,low.y))
	candidates.append(Vector2(high.x,low.y))
	var best_score := INF
	for candidate in candidates:
		var location: Vector2 = candidate.clamp(low,high)
		var rect := Rect2(location,panel.size)
		var score: float = location.distance_to(candidate)
		for obstacle in bodies:
			if obstacle.intersects(rect): score += 10000+rect.intersection(obstacle).get_area()
		var edge := mouth.clamp(rect.position,rect.end)
		var player_body: Rect2 = bodies[0]
		var corners := [player_body.position,Vector2(player_body.end.x,player_body.position.y),player_body.end,Vector2(player_body.position.x,player_body.end.y)]
		if range(4).any(func(i):return Geometry2D.segment_intersects_segment(edge,mouth,corners[i],corners[(i+1)%4])!=null): score += 10000
		if score<best_score:
			best_score = score
			panel.position = location
	panel.point_to(mouth)

func _process(_delta: float) -> void:
	if game and last_size != game.get_viewport_rect().size: layout()
	if panel and panel.visible: position_speech()

func snapshot() -> Dictionary:
	return {"visible":panel.visible,"responses_visible":responses.visible,"target_id":current_target.get("id",""),"role":current_target.get("role",""),"speaker":speaker.text,"text":body.text}
