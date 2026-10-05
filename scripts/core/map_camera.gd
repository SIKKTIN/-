extends Camera2D

const VIEW := Rect2(74,114,922,560)
const SCROLL_SPEED := 520.0
const DRAG_THRESHOLD := 12.0
const FOLLOW_SPEED := 10.0
var game
var panning: bool = false
var enabled_for_room: bool = false
var scroll_direction := Vector2.ZERO
var pointer_id: int = -2
var pointer_start := Vector2.ZERO
var pointer_last := Vector2.ZERO
var pointer_dragged := false
var _pointer_world_transform := Transform2D.IDENTITY
var following: bool = true
var _previous_target := Vector2.ZERO
var _target_sample_valid := false
var _follow_actor: int = -1

func configure(owner_game) -> void:
	game = owner_game
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	position_smoothing_enabled = false
	# EscapeGame owns the update order: movement -> camera -> screen prompts.
	set_process(false)
	reset()

func reset() -> void:
	panning = false
	pointer_id = -2
	if game.mini_map:
		game.mini_map.pointer_id = -2
	scroll_direction = Vector2.ZERO
	enabled_for_room = game.world.bounds.size.x > VIEW.size.x + 1 or game.world.bounds.size.y > VIEW.size.y + 1
	position = Vector2.ZERO
	if enabled_for_room:
		locate_selected()
	else:
		force_update_scroll()

func pan_by(delta: Vector2) -> void:
	if not enabled_for_room:
		return
	var map: Rect2 = game.world.bounds
	var low := map.position - VIEW.position
	var high := map.end - VIEW.end
	position = (position + delta).clamp(low, high.max(low))
	force_update_scroll()
	game.queue_redraw()

func manual_pan_by(delta: Vector2) -> void:
	if delta != Vector2.ZERO:
		following = false
		_target_sample_valid = false
	pan_by(delta)

func locate_selected() -> void:
	following = true
	_target_sample_valid = false
	if not enabled_for_room:
		return
	position = game.actors[game.selected_actor_id].position - VIEW.get_center()
	pan_by(Vector2.ZERO)

func interaction_blocked() -> bool:
	return game.get_tree().paused or (game.shop_panel != null and game.shop_panel.panel.visible)

func center_on(world_point: Vector2) -> void:
	following = false
	_target_sample_valid = false
	if enabled_for_room:
		position = world_point - VIEW.get_center()
		pan_by(Vector2.ZERO)

func over_ui(point: Vector2) -> bool:
	for control in game.get_node("HUD").get_children():
		if control is Control and control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point):
			return true
	return false

func begin_pointer(id: int, point: Vector2) -> bool:
	if pointer_id != -2 or not VIEW.has_point(point) or over_ui(point):
		return false
	pointer_id = id
	pointer_start = point
	pointer_last = point
	pointer_dragged = false
	_pointer_world_transform = game.get_global_transform_with_canvas().affine_inverse()
	return true

func move_pointer(point: Vector2) -> void:
	if not pointer_dragged and point.distance_to(pointer_start) >= DRAG_THRESHOLD:
		pointer_dragged = true
		manual_pan_by(pointer_start-point)
	elif pointer_dragged:
		manual_pan_by(pointer_last-point)
	pointer_last = point

func end_pointer(point: Vector2, cancelled: bool = false) -> void:
	if not cancelled and not pointer_dragged and point.distance_to(pointer_start) >= DRAG_THRESHOLD:
		move_pointer(point)
	if not cancelled and not pointer_dragged and VIEW.has_point(point) and not over_ui(point):
		# Keep the intended tap on the world seen at press time. Following can
		# continue while a finger is held, without shifting its command target.
		var world_point: Vector2 = _pointer_world_transform*point
		if not game.select_at(world_point):
			game.command_at(world_point)
	pointer_id = -2
	pointer_dragged = false

func tick(delta: float) -> void:
	scroll_direction = Vector2.ZERO
	if not game:
		return
	if not get_window().has_focus() or interaction_blocked():
		panning = false
		pointer_id = -2
		_target_sample_valid = false
		return
	if not enabled_for_room:
		return
	if panning or (pointer_id != -2 and pointer_dragged):
		_target_sample_valid = false
		return
	if game.mini_map and game.mini_map.pointer_id != -2:
		_target_sample_valid = false
		return
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if keys != Vector2.ZERO:
		scroll_direction = keys.normalized()
	if scroll_direction != Vector2.ZERO:
		manual_pan_by(scroll_direction * SCROLL_SPEED * delta)
	elif following and not game.actors[game.selected_actor_id].escaped:
		var target: Vector2 = game.actors[game.selected_actor_id].position-VIEW.get_center()
		var low: Vector2 = game.world.bounds.position-VIEW.position
		var high: Vector2 = (game.world.bounds.end-VIEW.end).max(low)
		target = target.clamp(low,high)
		var decay := exp(-FOLLOW_SPEED*delta)
		var next: Vector2
		if _target_sample_valid and _follow_actor == game.selected_actor_id and delta > 0:
			# Integrate a linearly moving target analytically. Lerp to just the
			# endpoint gives a different following distance on long/short frames.
			var velocity: Vector2 = (target-_previous_target)/delta
			var lag: Vector2 = velocity/FOLLOW_SPEED
			next = target-lag+(position-_previous_target+lag)*decay
		else:
			next = target+(position-target)*decay
		_previous_target = target
		_follow_actor = game.selected_actor_id
		_target_sample_valid = true
		if next.distance_squared_to(target) < 0.000001:
			next = target # Stop tiny residual subpixel movement while standing still.
		pan_by(next-position)

func _input(event: InputEvent) -> void:
	if not game:
		return
	if interaction_blocked():
		panning = false
		pointer_id = -2
		return
	# Handle native touches once; Godot also emulates mouse for ordinary UI buttons.
	if event is InputEventScreenTouch:
		if event.pressed:
			if begin_pointer(event.index,event.position):
				get_viewport().set_input_as_handled()
		elif pointer_id == event.index:
			end_pointer(event.position,event.canceled)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if pointer_id == event.index:
			move_pointer(event.position)
			get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		if VIEW.has_point(event.position) and not over_ui(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var pan_button: bool = event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))
		if event.pressed and pan_button and VIEW.has_point(event.position) and not over_ui(event.position):
			panning = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and panning and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT]:
			panning = false
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and begin_pointer(-1,event.position):
				get_viewport().set_input_as_handled()
			elif not event.pressed and pointer_id == -1:
				end_pointer(event.position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and panning:
		manual_pan_by(-event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_id == -1:
		move_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN] or event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and event.keycode == KEY_F:
			locate_selected()
			get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
	return {"offset": [position.x,position.y],"enabled":enabled_for_room,"following":following,"panning":panning,"viewport":[74,114,922,560],"edge_scroll":false,"pointer_active":pointer_id != -2,"drag_threshold":DRAG_THRESHOLD,"scroll_speed":SCROLL_SPEED}
