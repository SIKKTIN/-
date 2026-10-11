extends RefCounted

# Shared HUD nodes needed before the final fullscreen skin is constructed.
static func configure(game) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	game.add_child(layer)
	game.room_selector = OptionButton.new()
	game.room_selector.name = "RoomSelector"
	game.room_selector.z_index = 210 # Remains usable above a terminal result overlay.
	game.room_selector.position = Vector2(566,35)
	game.room_selector.size = Vector2(230,42)
	for index in range(game.ROOM_IDS.size()):
		game.room_selector.add_item(["R01 · 双通路", "R02 · 门边掩护", "R03 · 仓库交易所", "R04 · 黑工厂生活区"][index])
		game.room_selector.set_item_disabled(index,not FileAccess.file_exists("res://data/rooms/%s.json" % game.ROOM_IDS[index]))
	game.room_selector.select(game.ROOM_IDS.find(game.room_id))
	if game.room_config.get("demo_single_map",false): game.room_selector.disabled = true
	game.room_selector.item_selected.connect(func(index): game.load_room(game.ROOM_IDS[index]))
	layer.add_child(game.room_selector)
	for index in range(1):
		var card := Button.new()
		card.name = "ActorCard%d" % (index + 1)
		card.position = Vector2(1025, 154 + index * 102)
		card.size = Vector2(155, 84)
		card.pressed.connect(game.select_actor.bind(index))
		layer.add_child(card)
		game.cards.append(card)
	var reset_button := Button.new()
	reset_button.name = "ResetRound"
	reset_button.text = "重新开始  R"
	reset_button.position = Vector2(1025, 62)
	reset_button.size = Vector2(155, 42)
	reset_button.pressed.connect(game.reset_round)
	layer.add_child(reset_button)
	game.status_label = Label.new()
	game.status_label.name = "Status"
	game.status_label.position = Vector2(34, 686)
	game.status_label.add_theme_color_override("font_color", Color("303b46"))
	layer.add_child(game.status_label)
