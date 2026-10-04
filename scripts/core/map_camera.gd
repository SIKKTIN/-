extends Camera2D

const VIEW := Rect2(74,114,922,560)
var game
var panning: bool = false
var enabled_for_room: bool = false

func configure(owner_game) -> void:
	game = owner_game
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = false
	reset()

func reset() -> void:
	panning = false
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

func _input(event: InputEvent) -> void:
	if not game or not enabled_for_room:
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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		locate_selected()
		get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
	return {"offset": [position.x,position.y],"enabled":enabled_for_room,"panning":panning,"viewport":[74,114,922,560]}
