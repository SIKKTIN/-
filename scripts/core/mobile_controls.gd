extends Node

class StickPad extends Control:
	var controls
	func _draw() -> void:
		var center := size/2
		var radius := minf(size.x,size.y)/2-4
		draw_circle(center,radius,Color(0.95,0.92,0.86,0.65),true,-1,true)
		draw_circle(center,radius,Color("7d8b7e"),false,2,true)
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			var point: Vector2 = center+direction*(radius-12)
			draw_colored_polygon(PackedVector2Array([point+direction*5,point-direction*4+direction.orthogonal()*5,point-direction*4-direction.orthogonal()*5]),Color("8a9687"))
		var knob: Vector2 = center+controls.pad_offset*(radius*0.58)
		draw_circle(knob,22,Color("328b82"),true,-1,true)
		draw_circle(knob,22,Color("e6f3e9"),false,2,true)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				controls.begin_pad(-1,get_global_rect().position+event.position)
			elif controls.pad_pointer == -1:
				controls.release_pad()
			accept_event()

var game
var pad: StickPad
var pad_offset := Vector2.ZERO
var direction := Vector2.ZERO
var pad_pointer := -2
var controlled_id := -1
var keys: Dictionary = {}
var discarded_touches: Dictionary = {}
var buttons_held: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = StickPad.new()
	pad.name = "MovementJoystick"
	pad.controls = self
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	pad.z_index = 30
	pad.size = Vector2(136,136)
	game.get_node("HUD").add_child(pad)
	game.get_window().focus_exited.connect(cancel_input)

func inputs_blocked() -> bool:
	return not game.actor_is_controllable(game.selected_actor_id) or game.world_input_blocked() or (game.fullscreen_ui != null and game.fullscreen_ui.bag_open)

func is_moving() -> bool:
	return direction.length_squared() > 0.0001 and not inputs_blocked()

func is_moving_actor(id: int) -> bool:
	return game.selected_actor_id == id and is_moving()

func cancel_input(cancel_buttons: bool = true) -> void:
	if pad_pointer >= 0:
		discarded_touches[pad_pointer] = true
	if cancel_buttons:
		for id in buttons_held.keys():
			discarded_touches[id] = true
		buttons_held.clear()
	pad_pointer = -2
	controlled_id = -1
	keys.clear()
	direction = Vector2.ZERO
	pad_offset = Vector2.ZERO
	if pad:
		pad.queue_redraw()

func begin_pad(id: int, point: Vector2) -> bool:
	if inputs_blocked() or game.actors[game.selected_actor_id].escaped or pad_pointer != -2:
		return false
	pad_pointer = id
	update_pad(point)
	return true

func update_pad(point: Vector2) -> void:
	pad_offset = ((point-pad.get_global_rect().get_center())/(minf(pad.size.x,pad.size.y)*0.38)).limit_length(1)
	var magnitude := pad_offset.length()
	direction = Vector2.ZERO if magnitude <= 0.13 else pad_offset.normalized()*(magnitude-0.13)/0.87
	_claim_control()
	pad.queue_redraw()

func release_pad() -> void:
	pad_pointer = -2
	controlled_id = -1
	pad_offset = Vector2.ZERO
	_refresh_keyboard()
	pad.queue_redraw()

func _refresh_keyboard() -> void:
	direction = Vector2(float(keys.has(KEY_D) or keys.has(KEY_RIGHT))-float(keys.has(KEY_A) or keys.has(KEY_LEFT)),float(keys.has(KEY_S) or keys.has(KEY_DOWN))-float(keys.has(KEY_W) or keys.has(KEY_UP))).normalized()
	_claim_control()

func _claim_control(force: bool = false) -> void:
	if not is_moving() or (not force and controlled_id == game.selected_actor_id):
		return
	var id: int = game.selected_actor_id
	game.routines.take_control(id)
	game.orders.stop(id)
	game.skills.cancel(id,"移动当前伙伴，停止其操作；其他伙伴继续行动。")
	controlled_id = id

func _process(_delta: float) -> void:
	if game and inputs_blocked():
		cancel_input(game.world_input_blocked())

func tick(delta: float) -> void:
	if inputs_blocked():
		cancel_input(game.world_input_blocked())
		return
	if not is_moving():
		controlled_id = -1
		return
	var id: int = game.selected_actor_id
	var actor = game.actors[id]
	if actor.escaped:
		cancel_input()
		return
	_claim_control(game.orders.active.has(id) or not game.routines.manual.has(id))
	var push: bool = actor.skill_id == "strong"
	var speed: float = game.MOVE_SPEED*(game.attributes.move_efficiency(id) if game.attributes else 1.0)
	var moved: Vector2 = game.world.move_actor(actor,direction*speed*delta,push,85*delta)
	actor.moved_this_frame = moved.length_squared() > 0.001
	if actor.moved_this_frame:
		actor.facing = moved.normalized()
		actor.queue_redraw()
	if game.map_camera:
		game.map_camera.following = true
	if game.world.check_exit(actor):
		game.on_actor_escaped(id)
		cancel_input()

func _button_at(node: Node, point: Vector2):
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		var found = _button_at(child,point)
		if found != null:
			return found
	if node is Button and not node.disabled and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(point):
		return node
	return null

func _input(event: InputEvent) -> void:
	if not game:
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		# Native touches above are dispatched once. Godot also generates an
		# emulated mouse event, which would otherwise toggle an action twice.
		if not game.world_input_blocked() and game.map_camera.over_ui(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if discarded_touches.has(event.index):
			if not event.pressed:
				discarded_touches.erase(event.index)
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and event.index == pad_pointer:
			release_pad()
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and buttons_held.has(event.index):
			var held: Dictionary = buttons_held[event.index]
			buttons_held.erase(event.index)
			var b = held.button
			var target_unchanged: bool = held.get("target","") == "" or held.target == game.presentation.interaction.mobile_target_key
			if target_unchanged and not event.canceled and is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(event.position) and (held.actor_id == game.selected_actor_id or b in game.cards) and not game.world_input_blocked():
				b.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not game.world_input_blocked():
			if pad.visible and pad.get_global_rect().has_point(event.position):
				begin_pad(event.index,event.position)
				get_viewport().set_input_as_handled()
				return
			# Deliver independent right-finger presses; mouse emulation only
			# supports the first touch. Never dispatch through a modal blocker.
			var b = _button_at(game.get_node("HUD"),event.position)
			if b != null:
				buttons_held[event.index] = {"button":b,"actor_id":game.selected_actor_id,"target":game.presentation.interaction.mobile_target_key if game.fullscreen_ui and b == game.fullscreen_ui.action_button else ""}
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if discarded_touches.has(event.index) or buttons_held.has(event.index):
			get_viewport().set_input_as_handled()
		elif event.index == pad_pointer:
			update_pad(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != -1 and pad_pointer == -1:
		update_pad(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pad_pointer == -1:
		release_pad()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			if event.pressed and not inputs_blocked():
				keys[key] = true
			else:
				keys.erase(key)
			if pad_pointer == -2:
				_refresh_keyboard()
			get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
	return {"direction":[direction.x,direction.y],"pointer":pad_pointer,"controlled_id":controlled_id,"blocked":inputs_blocked(),"keyboard":keys.keys(),"held_buttons":buttons_held.size()}
