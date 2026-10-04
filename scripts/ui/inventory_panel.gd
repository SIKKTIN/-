extends Node

var game
var label: Label
var slots: Array[Button] = []
var selected_item: String = ""
var last_actor: int = -1
var use_button: Button
var drop_button: Button
var transfer_buttons: Array[Button] = []

func configure(owner_game) -> void:
	game = owner_game
	label = Label.new()
	label.name = "InventoryLabel"
	label.position = Vector2(1029, 450)
	label.add_theme_font_size_override("font_size", 14)
	game.get_node("HUD").add_child(label)
	for index in range(3):
		var slot := Button.new()
		slot.name = "InventorySlot%d" % index
		slot.position = Vector2(1026 + index * 51, 474)
		slot.size = Vector2(47, 48)
		slot.add_theme_font_size_override("font_size", 12)
		slot.pressed.connect(_select.bind(index))
		slot.focus_mode = Control.FOCUS_NONE
		game.get_node("HUD").add_child(slot)
		slots.append(slot)
	use_button = _button("使用", Vector2(1026, 529), func(): _action("use"))
	drop_button = _button("放下", Vector2(1104, 529), func(): _action("drop"))
	for receiver in range(3):
		var button := _button("", Vector2.ZERO, _give.bind(receiver))
		transfer_buttons.append(button)
	game.hint_label.position = Vector2(1029, 602)
	game.hint_label.size = Vector2(151, 42)
	game.hint_label.max_lines_visible = 2
	refresh()

func _button(text: String, point: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = point
	b.size = Vector2(74, 32)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	game.get_node("HUD").add_child(b)
	return b

func _action(kind: String) -> void:
	var result: Dictionary = game.inventory.try_use(game.selected_actor_id, selected_item) if kind == "use" else game.inventory.try_drop(game.selected_actor_id, selected_item)
	game.show_status(str(result.reason) if str(result.reason) != "" else "物品已放下。")
	refresh()

func _give(receiver: int) -> void:
	var result: Dictionary = game.inventory.try_transfer(game.selected_actor_id, receiver, selected_item)
	game.show_status(str(result.reason) if str(result.reason) != "" else "已交给伙伴%d。" % (receiver+1))
	refresh()

func _select(index: int) -> void:
	var bag: Array = game.inventory.items(game.selected_actor_id)
	selected_item = str(bag[index]) if index < bag.size() else ""
	refresh()

func refresh() -> void:
	var id: int = game.selected_actor_id
	if last_actor != id:
		selected_item = ""
		last_actor = id
	var bag: Array = game.inventory.items(id)
	if not bag.has(selected_item):
		selected_item = ""
	label.text = "背包 %d/%d · 钱 %d" % [bag.size(), game.inventory.capacity(id), game.inventory.wallet]
	label.add_theme_color_override("font_color", Color("a75d47") if bag.size() >= game.inventory.capacity(id) else Color("536052"))
	for index in range(slots.size()):
		var slot: Button = slots[index]
		slot.visible = index < game.inventory.capacity(id)
		slot.disabled = game.actors[id].escaped or game.phase != "playing"
		slot.theme = game.cards[0].theme
		if index < bag.size():
			var entry: Dictionary = game.inventory.instances[bag[index]]
			var definition: Dictionary = game.inventory.definitions.get(entry.definition_id, {})
			slot.text = str(definition.get("short", entry.definition_id))
			slot.icon = game.items_view.icon_for(str(entry.definition_id)) if game.items_view else null
			slot.add_theme_constant_override("icon_max_width", 22)
			slot.expand_icon = true
			if slot.icon:
				slot.text = ""
			slot.tooltip_text = "%s：%s" % [definition.get("name", entry.definition_id), definition.get("description", "点击选择物品")]
		else:
			slot.text = "空"
			slot.icon = game.items_view.icon_for("empty") if game.items_view else null
			if slot.icon:
				slot.text = ""
			slot.tooltip_text = "每格一件物品"
		slot.modulate = Color("aadfcb") if index < bag.size() and bag[index] == selected_item else Color.WHITE
	var owned: bool = game.inventory.owns(id, selected_item)
	use_button.disabled = not owned
	drop_button.disabled = not owned
	use_button.theme = game.cards[0].theme
	drop_button.theme = game.cards[0].theme
	drop_button.icon = game.items_view.icon_for("drop") if game.items_view else null
	drop_button.add_theme_constant_override("icon_max_width",16)
	drop_button.expand_icon = true
	var n := 0
	for receiver in range(3):
		var b: Button = transfer_buttons[receiver]
		b.visible = receiver != id
		if not b.visible:
			continue
		b.position = Vector2(1026 + n * 78, 566)
		b.text = "交给%d" % (receiver+1)
		b.theme = game.cards[0].theme
		b.disabled = not owned or not game.inventory.available(receiver)
		b.icon = game.items_view.icon_for("transfer") if game.items_view else null
		b.add_theme_constant_override("icon_max_width",16)
		b.expand_icon = true
		n += 1
