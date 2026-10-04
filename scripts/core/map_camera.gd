extends Camera2D

const VIEW := Rect2(74,114,922,560)
const EDGE_BAND := 24.0
const SCROLL_SPEED := 520.0
var game
var panning: bool = false
var enabled_for_room: bool = false
var scroll_direction := Vector2.ZERO

func configure(owner_game) -> void:
	game = owner_game
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = false
	reset()

func reset() -> void:
	panning = false
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

func locate_selected() -> void:
	if not enabled_for_room:
		return
	position = game.actors[game.selected_actor_id].position - VIEW.get_center()
	pan_by(Vector2.ZERO)

func interaction_blocked() -> bool:
	return game.get_tree().paused or (game.shop_panel != null and game.shop_panel.panel.visible)

func edge_direction(point: Vector2) -> Vector2:
	# The edge is the visible map panel, not the outer window or right sidebar.
	if not VIEW.has_point(point):
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if point.x < VIEW.position.x + EDGE_BAND:
		direction.x = -1
	elif point.x >= VIEW.end.x - EDGE_BAND:
		direction.x = 1
	if point.y < VIEW.position.y + EDGE_BAND:
		direction.y = -1
	elif point.y >= VIEW.end.y - EDGE_BAND:
		direction.y = 1
	return direction.normalized()

func _process(delta: float) -> void:
	scroll_direction = Vector2.ZERO
	if not game or not enabled_for_room:
		return
	if not get_window().has_focus() or interaction_blocked():
		panning = false
		return
	if panning:
		return
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if keys != Vector2.ZERO:
		scroll_direction = keys.normalized()
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# Give interaction icons priority over automatic scrolling while hovered.
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered == null:
			scroll_direction = edge_direction(get_viewport().get_mouse_position())
	if scroll_direction != Vector2.ZERO:
		pan_by(scroll_direction * SCROLL_SPEED * delta)

func _input(event: InputEvent) -> void:
	if not game or not enabled_for_room:
		return
	if interaction_blocked():
		panning = false
		return
	if event is InputEventMouseButton:
		var pan_button: bool = event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))
		if event.pressed and pan_button and VIEW.has_point(event.position):
			panning = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and panning and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT]:
			panning = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and panning:
		pan_by(-event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN] or event.physical_keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.echo and event.keycode == KEY_F:
			locate_selected()
			get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
	return {"offset": [position.x,position.y],"enabled":enabled_for_room,"panning":panning,"viewport":[74,114,922,560],"edge_band":EDGE_BAND,"scroll_speed":SCROLL_SPEED,"scroll_direction":[scroll_direction.x,scroll_direction.y]}
