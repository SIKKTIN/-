extends Node

var game
var panel: Panel
var title: Label
var offers: ItemList
var buy: Button
var sell: Button
var merchant_id: String = ""
var actor_id: int = -1
var listed_ids: Array = []

func configure(owner_game) -> void:
	game = owner_game
	panel = Panel.new()
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
	notice.text = "出售：先选右侧背包物品。交易时巡逻继续。"
	notice.add_theme_font_size_override("font_size", 14)
	panel.add_child(notice)
	offers = ItemList.new()
	offers.position = Vector2(18, 80)
	offers.size = Vector2(454, 205)
	offers.fixed_icon_size = Vector2i(24, 24)
	panel.add_child(offers)
	buy = _button("购买所选", Vector2(18, 299), func(): transact(true))
	sell = _button("卖出背包所选", Vector2(168, 299), func(): transact(false))
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
	if game.trade.reason(game.selected_actor_id, id) != "":
		return
	merchant_id = id
	actor_id = game.selected_actor_id
	listed_ids.clear()
	panel.visible = true
	refresh()

func close() -> void:
	if panel:
		panel.visible = false
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
			offers.add_item("%s  ·  买 %d / 卖 %d" % [def.name, def.sell_price, def.buy_price], game.items_view.icon_for(str(def.id)))
		if offers.item_count > 0:
			offers.select(0)
	buy.disabled = offers.get_selected_items().is_empty()
	sell.disabled = not game.inventory.owns(actor_id, game.inventory_panel.selected_item)

func transact(purchase: bool) -> void:
	refresh()
	if not panel.visible:
		return
	var result: Dictionary
	if purchase:
		var selected := offers.get_selected_items()
		if selected.is_empty():
			return
		result = game.trade.try_buy(actor_id, merchant_id, str(listed_ids[selected[0]]))
	else:
		result = game.trade.try_sell(actor_id, merchant_id, game.inventory_panel.selected_item)
	game.show_status(str(result.reason))
	game.inventory_panel.refresh()
	refresh()
