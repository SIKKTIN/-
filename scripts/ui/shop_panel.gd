extends Node

var game
var panel: Panel
var blocker: ColorRect
var title: Label
var offers: ItemList
var buy: Button
var merchant_id: String = ""
var actor_id: int = -1
var listed_ids: Array = []

func configure(owner_game) -> void:
	game = owner_game
	blocker = ColorRect.new()
	blocker.name = "ShopMapBlocker"
	blocker.position = Vector2(74,114)
	blocker.size = Vector2(922,560)
	blocker.color = Color(0,0,0,0.18)
	blocker.z_index = 100
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	game.get_node("HUD").add_child(blocker)
	panel = Panel.new()
	panel.z_index = 101
	panel.name = "MerchantShop"
	panel.position = Vector2(360, 200)
	panel.size = Vector2(490, 355)
	panel.theme = game.cards[0].theme
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2ebdd")
	paper.border_color = Color("536052")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", paper)
	game.get_node("HUD").add_child(panel)
	title = Label.new()
	title.position = Vector2(18, 15)
	panel.add_child(title)
	var notice := Label.new()
	notice.position = Vector2(18, 47)
	notice.text = "仅可购买 · 营业：12–14 / 18–20，交易时钟继续。"
	notice.add_theme_font_size_override("font_size", 14)
	panel.add_child(notice)
	offers = ItemList.new()
	offers.position = Vector2(18, 80)
	offers.size = Vector2(454, 205)
	offers.fixed_icon_size = Vector2i(24, 24)
	panel.add_child(offers)
	buy = _button("购买所选", Vector2(18, 299), transact, 282)
	_button("关闭", Vector2(348, 299), close, 120)
	close()

func _button(text: String, point: Vector2, callback: Callable, width: float = 142) -> Button:
	var b := Button.new()
	b.text = text
	b.position = point
	b.size = Vector2(width, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	panel.add_child(b)
	return b

func open(id: String) -> void:
	if game.phase != "playing":
		return
	if game.trade.reason(game.selected_actor_id, id) != "":
		return
	if game.routine_panel:
		game.routine_panel.close()
	if game.routines:
		game.routines.take_control(game.selected_actor_id)
	merchant_id = id
	actor_id = game.selected_actor_id
	listed_ids.clear()
	panel.visible = true
	blocker.visible = true
	if game.schedule:
		game.schedule.close()
	if game.developer_settings:
		game.developer_settings.close()
	if game.presentation and game.presentation.interaction:
		game.presentation.interaction.refresh()
	refresh()

func close() -> void:
	if panel:
		panel.visible = false
	if blocker:
		blocker.visible = false
	merchant_id = ""
	actor_id = -1
	listed_ids.clear()

func refresh() -> void:
	if not panel.visible:
		return
	if game.selected_actor_id != actor_id or game.trade.reason(actor_id, merchant_id) != "":
		close()
		return
	title.text = "商人 · 伙伴%d · 钱 %d" % [actor_id + 1, game.inventory.wallet]
	var stock: Array = game.trade.merchants[merchant_id].stock
	if listed_ids != stock:
		listed_ids = stock.duplicate()
		offers.clear()
		for id in listed_ids:
			var def: Dictionary = game.inventory.definitions[game.inventory.instances[id].definition_id]
			offers.add_item("%s  ·  价格 %d" % [def.name, def.sell_price], game.items_view.icon_for(str(def.id)))
		if offers.item_count > 0:
			offers.select(0)
	buy.disabled = offers.get_selected_items().is_empty()

func transact() -> void:
	refresh()
	if not panel.visible:
		return
	var selected := offers.get_selected_items()
	if selected.is_empty():
		return
	var result: Dictionary = game.trade.try_buy(actor_id, merchant_id, str(listed_ids[selected[0]]))
	game.show_status(str(result.reason))
	game.inventory_panel.refresh()
	refresh()
