extends Node

const Slot = preload("res://scripts/ui/quick_slot_button.gd")
var ui
var buttons: Array[Button] = []

func configure(owner_ui):
	ui = owner_ui
	for index in range(4):
		var button := Slot.new()
		button.name = "QuickUse%d" % (index+1)
		button.index = index
		button.font = ui.font
		button.z_index = 60
		button.pressed.connect(func(): ui.game.quick_items.activate(button.index))
		ui.game.get_node("HUD").add_child(button)
		buttons.append(button)

func layout():
	var safe: Rect2 = ui.safe_area()
	var edge := 50.0 if safe.size.y < 600 else 54.0
	var bottom: float = ui.safe_area().end.y-ui.action_button.size.y-24
	# Stay at the safe edge when the player moves the separate action buttons.
	var x: float = safe.end.x-edge
	for index in range(4):
		buttons[index].size = Vector2.ONE*edge
		buttons[index].position = Vector2(x,bottom-(4-index)*edge-(3-index)*6)

func refresh():
	var game = ui.game
	var showing: bool = not game.world_input_blocked() and not ui.bag_open and not (ui.button_layout and ui.button_layout.editing)
	for index in range(4):
		var button = buttons[index]
		button.visible = showing
		if not showing: continue
		var state: Dictionary = game.quick_items.state(index)
		button.update_state(state,ui.inventory_drawer.icon_for(str(state.kind)))
