extends Control

var game
var button: Button

func configure(owner_game) -> void:
	game = owner_game
	name = "EditorPreviewReturn"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.text = "F10 返回编辑"
	button.theme = game.cards[0].theme
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(172,36)
	button.z_index = 100
	button.pressed.connect(func(): get_tree().quit())
	add_child(button)
	_process(0)

func _process(_delta: float) -> void:
	if game:
		button.visible = not game.world_input_blocked()
		button.position = Vector2(maxf(460,get_viewport_rect().size.x/2-86),16)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		get_tree().quit()
