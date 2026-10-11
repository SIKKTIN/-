extends Node

# Selection/actions are shared with the shop. InventoryDrawer owns all layout,
# icons, item details and enabled states; there is no hidden legacy bag UI.
var game
var slots: Array[Button] = []
var selected_item := ""
var use_button: Button
var drop_button: Button
var _display_key: Array = []

func configure(owner_game) -> void:
	game = owner_game
	for index in range(3):
		var slot := Button.new()
		slot.name = "InventorySlot%d" % index
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(_select.bind(index))
		game.get_node("HUD").add_child(slot)
		slots.append(slot)
	use_button = _button("使用",func(): _action("use"))
	drop_button = _button("丢弃",func(): _action("drop"))
	refresh()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	game.get_node("HUD").add_child(button)
	return button

func _action(kind: String) -> void:
	var id: int = game.PLAYER_ACTOR_ID
	var result: Dictionary = game.inventory.try_use(id,selected_item) if kind=="use" else game.inventory.try_drop(id,selected_item)
	game.show_status(str(result.reason) if not str(result.reason).is_empty() else "物品已放下。")
	refresh()

func _select(index: int) -> void:
	var bag: Array = game.inventory.items(game.PLAYER_ACTOR_ID)
	selected_item = str(bag[index]) if index>=0 and index<bag.size() else ""
	refresh()
	if game.shop_panel: game.shop_panel.refresh()

func refresh() -> void:
	var bag: Array = game.inventory.items(game.PLAYER_ACTOR_ID)
	if not bag.has(selected_item): selected_item = ""
	var key := [bag.duplicate(),selected_item,game.inventory.capacity(game.PLAYER_ACTOR_ID),game.phase]
	if key==_display_key: return
	_display_key = key
	if game.fullscreen_ui: game.fullscreen_ui.refresh_inventory()
