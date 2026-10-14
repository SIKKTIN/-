extends CanvasLayer

const Art = preload("res://scripts/ui/nine_point_art.gd")
const Seating = preload("res://scripts/ui/nine_point_seating.gd")
const HudArt = preload("res://scripts/ui/hud_skin.gd")
const Rules = preload("res://scripts/minigames/nine_point_round.gd")
const FONT = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
const DESIGN := Vector2(1600, 900)
const ASSET_DIR := "res://art/ui/nine_point_v1/"
const POSE_DIR := "res://art/ui/nine_point_v2/"

class Board extends Control:
	var ui
	func _draw(): ui.paint(self)

class RivetButton extends Button:
	func _draw(): preload("res://scripts/ui/hud_skin.gd").rivets(self,size)

var controller
var opened := false
var busy := false
var notice := "选择人数与每人注额，确认后发牌。"
var screen: Control
var board: Board
var background: Texture2D
var poses := {}
var primary: Button
var secondary: Button
var exit_button: Button
var count_picker: OptionButton
var stakes: Array = []
var modal: Panel
var modal_cover: ColorRect
var modal_text: Label
var modal_yes: Button
var modal_no: Button
var rules_mode := false
var revealed := false
var deal_progress := 1.0
var payout_progress := 1.0
var dealing_first := true
var animation: Tween
var asset_bytes := 0
var art_load_ms := 0.0
var paint_count := 0
var _focus_before: WeakRef

func _ready():
	layer = 220
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color("172420")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	board = Board.new()
	board.ui = self
	board.size = DESIGN
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(board)
	exit_button = button("离桌 Esc",Rect2(24,16,145,48),controller.request_close)
	button("规则",Rect2(1480,16,96,48),show_rules)
	count_picker = OptionButton.new()
	count_picker.position = Vector2(200,16)
	count_picker.size = Vector2(190,48)
	count_picker.add_theme_font_override("font",FONT)
	count_picker.add_theme_font_size_override("font_size",22)
	HudArt.button(count_picker)
	for count in [2,3,4]: count_picker.add_item("%d人牌局" % count,count)
	count_picker.select(2)
	count_picker.item_selected.connect(func(index): controller.player_count = index+2; refresh())
	board.add_child(count_picker)
	for i in Rules.STAKES.size():
		var amount: int = Rules.STAKES[i]
		var b := button("练习" if amount == 0 else str(amount),Rect2(565+i*87,606,79,48),func(): controller.amount = amount; refresh())
		stakes.append(b)
	primary = button("确认押注",Rect2(1050,758,285,68),_primary,true)
	secondary = button("离桌",Rect2(1350,758,225,68),_secondary)
	modal_cover = ColorRect.new()
	modal_cover.color = Color(0.04,0.08,0.07,0.65)
	modal_cover.size = DESIGN
	board.add_child(modal_cover)
	modal = Panel.new()
	modal.position = Vector2(470,270)
	modal.size = Vector2(660,370)
	modal.add_theme_stylebox_override("panel",HudArt.box("paper"))
	board.add_child(modal)
	modal_text = Label.new()
	modal_text.position = Vector2(28,22)
	modal_text.size = Vector2(604,255)
	modal_text.add_theme_font_override("font",FONT)
	modal_text.add_theme_font_size_override("font_size",21)
	modal_text.add_theme_color_override("font_color",Art.INK)
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.add_child(modal_text)
	modal_yes = button("确定",Rect2(34,295,282,54),_modal_yes,true,modal)
	modal_no = button("继续牌局",Rect2(342,295,282,54),func(): modal.hide(); primary.grab_focus(),false,modal)
	modal.hide()
	modal_cover.hide()
	modal.visibility_changed.connect(func(): modal_cover.visible = modal.visible)
	get_viewport().size_changed.connect(layout)
	layout()
	screen.hide()

func button(title: String, rect: Rect2, action: Callable, accent := false, parent: Node = null) -> Button:
	var b := RivetButton.new()
	b.text = title
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",FONT)
	b.add_theme_font_size_override("font_size",23)
	b.add_theme_color_override("font_focus_color",Color("faf5e9") if accent else Art.INK)
	HudArt.button(b,accent)
	b.pressed.connect(action)
	(parent if parent != null else board).add_child(b)
	return b

func load_art():
	if background != null: return
	var started := Time.get_ticks_usec()
	background = load(ASSET_DIR+"background.res")
	asset_bytes += background.get_image().get_data_size()
	var ids := ["lin", "zhou", "xu", "lu"]
	for id in ids:
		poses[id] = {}
		for view in ["front", "back", "side"]:
			var texture: Texture2D = load(POSE_DIR+id+"_"+view+".res")
			poses[id][view] = texture
			asset_bytes += texture.get_image().get_data_size()
	art_load_ms = (Time.get_ticks_usec()-started)/1000.0

func show_table():
	load_art()
	_focus_before = weakref(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner() else null
	opened = true
	busy = false
	revealed = false
	screen.show()
	layout()
	refresh()
	primary.grab_focus()

func hide_table():
	if animation: animation.kill()
	busy = false
	opened = false
	screen.hide()
	modal.hide()
	if _focus_before and is_instance_valid(_focus_before.get_ref()): _focus_before.get_ref().grab_focus()
	# Do not keep every seated view resident after leaving the card room.
	background = null
	poses.clear()
	asset_bytes = 0

func layout():
	if not board: return
	var viewport := get_viewport().get_visible_rect().size
	var ratio := minf(viewport.x/DESIGN.x,viewport.y/DESIGN.y)
	board.scale = Vector2.ONE*ratio
	board.position = (viewport-DESIGN*ratio)/2

func refresh():
	if not board: return
	var betting: bool = controller.round_model.state == "betting"
	var result: bool = controller.round_model.state == "result" and revealed
	count_picker.disabled = not betting or busy
	count_picker.select(controller.player_count-2)
	for i in stakes.size():
		stakes[i].visible = betting
		stakes[i].disabled = busy
		HudArt.button(stakes[i],Rules.STAKES[i] == controller.amount)
	primary.text = ("练习一局 E" if controller.amount == 0 else "确认押注 %d E" % controller.amount) if betting else "再来一局 E" if result else "摸第二张 E"
	secondary.text = "离桌 Esc" if betting or result else "停牌比点 空格"
	primary.disabled = busy or (betting and not controller.bet_reason().is_empty())
	secondary.disabled = busy
	board.queue_redraw()

func _primary():
	if busy or modal.visible: return
	match controller.round_model.state:
		"betting": controller.confirm_bet()
		"decision": controller.decide(true)
		"result":
			controller.prepare()
			revealed = false
			notice = "选择人数与每人注额，确认后发牌。"
			refresh()

func _secondary():
	if busy or modal.visible: return
	if controller.round_model.state == "decision": controller.decide(false)
	else: controller.request_close()

func animate_deal():
	busy = true
	revealed = false
	deal_progress = 0
	dealing_first = true
	payout_progress = 0
	refresh()
	animation = create_tween()
	animation.tween_method(func(value): deal_progress = value; board.queue_redraw(),0.0,1.0,0.48)
	animation.tween_callback(func(): busy = false; refresh())

func animate_reveal(_drew: bool):
	busy = true
	revealed = false
	deal_progress = 0.35
	dealing_first = false
	refresh()
	animation = create_tween()
	animation.tween_method(func(value): deal_progress = value; board.queue_redraw(),0.35,1.0,0.35)
	animation.tween_interval(0.3)
	animation.tween_callback(func(): revealed = true; notice = controller.round_model.result_text(); board.queue_redraw())
	animation.tween_method(func(value): payout_progress = value; board.queue_redraw(),0.0,1.0,0.55)
	animation.tween_callback(func(): busy = false; refresh())

func show_rules():
	rules_mode = true
	modal_text.text = "九点 · 2—4人\n每人先拿一张，可停牌或再摸一张，最多两张。\nA为1点，2—9按牌面，10/J/Q/K为0点。\n相加只取个位：7＋8＝15，算5点。\n最高点赢奖池；并列平分，不能整分的零钱随机分给并列赢家。\n发牌前同额押注；发牌后离桌视为弃局。"
	modal_yes.text = "知道了"
	modal_no.hide()
	modal.show()
	modal_yes.grab_focus()

func show_forfeit():
	rules_mode = false
	modal_text.text = "发牌后离桌视为弃局。\n\n本局已押 %d，离桌后不能退回。其他牌友将完成本局并分配奖池。" % controller.round_model.stake
	modal_yes.text = "弃局离桌"
	modal_no.show()
	modal.show()
	modal_no.grab_focus()

func _modal_yes():
	modal.hide()
	if not rules_mode: controller.close()
	else: primary.grab_focus()

func _input(event: InputEvent):
	if not opened or not event is InputEventKey: return
	# Consume game shortcuts while seated, including R restart and 1–4 items.
	if not event.pressed or event.echo: return
	if modal.visible and event.keycode == KEY_TAB:
		if modal_no.visible and modal_yes.has_focus(): modal_no.grab_focus()
		else: modal_yes.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		if modal.visible: modal.hide(); primary.grab_focus()
		else: controller.request_close()
	elif not modal.visible and event.keycode == KEY_E: _primary()
	elif not modal.visible and event.keycode == KEY_SPACE: _secondary()
	elif not modal.visible and not busy and controller.round_model.state == "betting" and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		controller.amount = Rules.STAKES[event.keycode-KEY_1+1]
		refresh()
	elif event.keycode in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: return
	get_viewport().set_input_as_handled()

func seat_for(index: int) -> int:
	return [0,1,2,3][index]

func paint(canvas: CanvasItem):
	if not opened or background == null: return
	paint_count += 1
	Seating.draw(canvas,background,poses,controller.player_count)
	Art.plate(canvas,Rect2(580,16,510,48))
	Art.text(canvas,FONT,"九点 · 第%d局" % (controller.rounds_played+1 if controller.round_model.state != "result" else controller.rounds_played),Rect2(590,16,490,48),28)
	Art.plate(canvas,Rect2(1280,16,180,48))
	Art.text(canvas,FONT,"余额 %d" % controller.game.inventory.wallet,Rect2(1284,16,172,48),24)
	var model = controller.round_model
	var betting: bool = model.state == "betting"
	var badges := [Rect2(510,742,166,80),Rect2(555,96,166,80),Rect2(80,410,166,80),Rect2(1370,410,166,80)]
	var cards := [Vector2(694,578),Vector2(714,231),Vector2(421,365),Vector2(1100,365)]
	for i in controller.player_count:
		Art.plate(canvas,badges[i],"selected" if revealed and i in model.winners else "paper")
		Art.text(canvas,FONT,controller.NAMES[i],Rect2(badges[i].position+Vector2(0,3),Vector2(166,33)),24)
		var balance: int = controller.game.inventory.wallet if i == 0 else int(controller.npc_banks[i-1])
		var money_label := "押%d · 得%d" % [model.stake,model.payouts[i]] if revealed else "余额%d · 押%d" % [balance,controller.amount if betting else model.stake]
		Art.text(canvas,FONT,money_label,Rect2(badges[i].position+Vector2(2,38),Vector2(162,30)),18)
		var status := "待押注" if betting else "等待" if not revealed else "%d点" % Rules.points(model.hands[i])
		if i == 0 and not betting: status = "弃局" if model.forfeited else "轮到你" if model.state == "decision" else "%d点" % Rules.points(model.hands[0])
		Art.text(canvas,FONT,status,Rect2(badges[i].position+Vector2(0,84),Vector2(166,30)),21,Color("f3ecd9"))
		for j in 2:
			if betting and i == 0: continue
			var origin: Vector2 = cards[i]+Vector2(j*90,0) if i < 2 else cards[i]+Vector2(0,j*113)
			var empty: bool = betting or j >= model.hands[i].size()
			if not empty and not is_equal_approx(deal_progress,1) and (dealing_first or j > 0): origin = Vector2(948,327).lerp(origin,deal_progress)
			var card_value := -1
			if not empty and (i == 0 or revealed): card_value = int(model.hands[i][j])
			Art.card(canvas,FONT,Rect2(origin,Vector2(78,106)),card_value,empty)
		if revealed and i != 0:
			var line := "%d点（停牌）" % Rules.points(model.hands[i])
			if model.hands[i].size() == 2: line = "%d＋%d → %d点" % [Rules.card_value(model.hands[i][0]),Rules.card_value(model.hands[i][1]),Rules.points(model.hands[i])]
			Art.text(canvas,FONT,line,Rect2(cards[i]+Vector2(-10,-32),Vector2(195,27)),20,Color("f5ecd4"))
	Art.card(canvas,FONT,Rect2(944,328,60,84))
	var pot_value: int = controller.amount*controller.player_count if betting else model.pot
	Art.plate(canvas,Rect2(695,405,220,112))
	Art.text(canvas,FONT,"预计奖池" if betting else "练习局" if model.stake == 0 else "本局奖池",Rect2(703,413,204,30),23)
	Art.text(canvas,FONT,str(pot_value),Rect2(703,449,204,44),37)
	Art.text(canvas,FONT,"最高点获胜 · 并列平分",Rect2(689,522,232,27),18,Color("f5ecd4"))
	if not betting and model.stake > 0:
		var recipients: Array = model.winners if revealed else [-1]
		var destinations := [Vector2(870,725),Vector2(910,207),Vector2(380,485),Vector2(1235,485)]
		for recipient in recipients:
			var cash_position := Vector2(800,366)
			if recipient >= 0: cash_position = cash_position.lerp(destinations[recipient],payout_progress)
			for i in (4 if recipients.size()>1 else 7):
				var p := cash_position+Vector2((i%4)*18-28,(i/4)*14)
				canvas.draw_circle(p,11,Color("bd9250"),true,-1,true)
				canvas.draw_circle(p,8,Color("65472c"),false,1.5,true)
	var hint := "确认扣款后发牌" if betting else "派奖完成，可再来一局" if revealed else "最多两张，点数相加只取个位"
	Art.text(canvas,FONT,hint,Rect2(1030,838,545,37),20,Color("eee6d5"))
	if betting:
		Art.plate(canvas,Rect2(555,555,448,114))
		Art.text(canvas,FONT,"每人押注 · 全员同额",Rect2(565,561,428,35),23)
		var reason: String = controller.bet_reason()
		if not reason.is_empty(): Art.text(canvas,FONT,reason,Rect2(440,525,730,36),21,Color("ffe1a0"))
	elif model.state == "decision":
		Art.plate(canvas,Rect2(920,640,200,52))
		Art.text(canvas,FONT,"当前 %d 点" % Rules.points(model.hands[0]),Rect2(925,640,190,52),26)
	elif revealed:
		Art.text(canvas,FONT,model.result_text(),Rect2(510,567,590,40),26,Color("ffe1a0"))
		Art.plate(canvas,Rect2(920,626,218,82))
		Art.text(canvas,FONT,"你的点数 %d" % Rules.points(model.hands[0]),Rect2(925,632,208,35),24)
		var hand: Array = model.hands[0]
		var formula := "%d点（停牌）" % Rules.points(hand)
		if hand.size() == 2: formula = "%d＋%d → %d点" % [Rules.card_value(hand[0]),Rules.card_value(hand[1]),Rules.points(hand)]
		Art.text(canvas,FONT,formula,Rect2(925,670,208,30),19)
