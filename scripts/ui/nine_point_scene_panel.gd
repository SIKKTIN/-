extends CanvasLayer

const Art = preload("res://scripts/ui/nine_point_art.gd")
const HudArt = preload("res://scripts/ui/hud_skin.gd")
const Rules = preload("res://scripts/minigames/nine_point_round.gd")
const Scratch = preload("res://scripts/ui/nine_point_scratch.gd")
const FONT = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
const DESIGN := Vector2(420,460)
class Board extends Control:
	var ui
	func _draw(): ui.paint(self)
var controller
var opened := false
var busy := false
var revealed := false
var known_cards := 0
var scratch_index := -1
var screen: Control
var board: Board
var scratch
var primary: Button
var secondary: Button
var count_picker: OptionButton
var stakes: Array = []
var modal: Panel
var modal_text: Label
var modal_yes: Button
var modal_no: Button
var rules_mode := false
var animation: Tween
var background: Texture2D
var poses := {}
var asset_bytes := 0
var art_load_ms := 0.0
var paint_count := 0
var notice := ""
var event_toast: Panel
var event_text: Label

func _ready():
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	event_toast = Panel.new()
	event_toast.position = Vector2(16,132)
	event_toast.size = Vector2(280,72)
	event_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_toast.add_theme_stylebox_override("panel",HudArt.box("paper"))
	screen.add_child(event_toast)
	event_text = Label.new()
	event_text.position = Vector2(12,8)
	event_text.size = Vector2(256,56)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_text.add_theme_font_override("font",FONT)
	event_text.add_theme_font_size_override("font_size",17)
	event_text.add_theme_color_override("font_color",Art.INK)
	event_toast.add_child(event_text)
	board = Board.new()
	board.ui = self
	board.size = DESIGN
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(board)
	count_picker = OptionButton.new()
	count_picker.position = Vector2(120,100)
	count_picker.size = Vector2(180,44)
	count_picker.add_theme_font_override("font",FONT)
	count_picker.add_theme_font_size_override("font_size",22)
	HudArt.button(count_picker)
	for count in [2,3,4]: count_picker.add_item("%d人牌局" % count,count)
	count_picker.select(2)
	count_picker.item_selected.connect(func(index): controller.player_count = index+2; refresh())
	board.add_child(count_picker)
	for i in Rules.STAKES.size():
		var amount: int = Rules.STAKES[i]
		stakes.append(button("练习" if amount == 0 else str(amount),Rect2(14+i*79,188,74,46),func(): controller.amount = amount; refresh()))
	primary = button("确认押注 E",Rect2(16,352,190,54),_primary,true)
	secondary = button("停牌 空格",Rect2(216,352,188,54),_secondary)
	button("离桌 Esc",Rect2(16,416,154,34),controller.request_close)
	button("规则",Rect2(300,416,104,34),show_rules)
	scratch = Scratch.new()
	scratch.position = Vector2(222,93)
	scratch.size = Vector2(170,228)
	board.add_child(scratch)
	scratch.uncovered.connect(_scratch_finished)
	scratch.hide()
	modal = Panel.new()
	modal.size = DESIGN
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_theme_stylebox_override("panel",HudArt.box("paper"))
	board.add_child(modal)
	modal_text = Label.new()
	modal_text.position = Vector2(20,20)
	modal_text.size = Vector2(380,320)
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_text.add_theme_font_override("font",FONT)
	modal_text.add_theme_font_size_override("font_size",19)
	modal_text.add_theme_color_override("font_color",Art.INK)
	modal.add_child(modal_text)
	modal_yes = button("确定",Rect2(16,365,188,58),_modal_yes,true,modal)
	modal_no = button("继续牌局",Rect2(216,365,188,58),_hide_modal,false,modal)
	modal.hide()
	get_viewport().size_changed.connect(layout)
	screen.hide()

func button(title: String, rect: Rect2, action: Callable, accent := false, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = title
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",FONT)
	b.add_theme_font_size_override("font_size",21)
	HudArt.button(b,accent)
	b.pressed.connect(action)
	(parent if parent != null else board).add_child(b)
	return b

func load_art():
	if background != null: return
	var started := Time.get_ticks_usec()
	background = load("res://art/ui/nine_point_v1/background.res")
	asset_bytes = background.get_image().get_data_size()
	for id in ["lin","zhou","xu","lu"]:
		poses[id] = {}
		for view in ["front","back","side"]:
			var texture: Texture2D = load("res://art/ui/nine_point_v2/"+id+"_"+view+".res")
			poses[id][view] = texture
			asset_bytes += texture.get_image().get_data_size()
	art_load_ms = (Time.get_ticks_usec()-started)/1000.0

func show_table():
	load_art()
	opened = true
	busy = false
	revealed = false
	known_cards = 0
	scratch_index = -1
	screen.show()
	layout()
	refresh()
	primary.grab_focus()

func hide_table():
	if animation: animation.kill()
	busy = false
	opened = false
	scratch_index = -1
	scratch.hide()
	screen.hide()
	modal.hide()
	background = null
	poses.clear()
	asset_bytes = 0

func layout():
	if not board: return
	var viewport := get_viewport().get_visible_rect().size
	var ratio := minf(viewport.x/1600.0,viewport.y/900.0)
	board.scale = Vector2.ONE*ratio
	board.position = viewport-DESIGN*ratio-Vector2(14,14)*ratio
	event_toast.scale = Vector2.ONE*minf(viewport.x/1200.0,viewport.y/720.0)
	event_toast.position = Vector2(16,132)*event_toast.scale
	if opened: controller.frame_table()

func _process(_delta: float):
	if not opened: return
	# Existing pause/settings/planner UI retains precedence over this local panel.
	screen.visible = not controller.game.fullscreen_ui.menu.visible and not controller.game.schedule.panel.visible and not controller.game.developer_settings.panel.visible
	event_toast.visible = controller.game.elapsed < controller.game.status_until
	if event_toast.visible: event_text.text = controller.game.status_text

func refresh():
	if not board: return
	var betting: bool = controller.round_model.state == "betting"
	var scratching := scratch_index >= 0
	count_picker.visible = betting
	count_picker.disabled = busy
	count_picker.select(controller.player_count-2)
	for i in stakes.size():
		stakes[i].visible = betting
		stakes[i].disabled = busy
		HudArt.button(stakes[i],Rules.STAKES[i] == controller.amount)
	primary.text = "直接翻开 E" if scratching else "确认押注 E" if betting else "再来一局 E" if revealed else "摸第二张 E"
	primary.size.x = 388 if scratching or betting or revealed else 190
	secondary.visible = not scratching and not betting and not revealed
	primary.disabled = busy or (betting and not controller.bet_reason().is_empty())
	secondary.disabled = busy or known_cards == 0
	board.queue_redraw()
	if controller.world_view: controller.world_view.queue_redraw()

func _primary():
	if busy or modal.visible: return
	if scratch_index >= 0: scratch.reveal_all(); return
	match controller.round_model.state:
		"betting": controller.confirm_bet()
		"decision": controller.decide(true)
		"result":
			known_cards = 0
			revealed = false
			controller.prepare()
			refresh()

func _secondary():
	if busy or modal.visible or scratch_index >= 0: return
	controller.decide(false)

func begin_scratch(index: int):
	if animation: animation.kill()
	scratch_index = index
	busy = false
	revealed = false
	scratch.position = Vector2(125,93) if index == 0 else Vector2(222,93)
	scratch.show()
	scratch.reset(int(controller.round_model.hands[0][index]))
	refresh()

func _scratch_finished():
	if not opened or scratch_index < 0: return
	known_cards = scratch_index+1
	var finished_second := scratch_index == 1
	scratch_index = -1
	scratch.hide()
	if finished_second: controller.finish_reveal()
	else: refresh()

func animate_deal():
	known_cards = 0
	begin_scratch(0)

func animate_reveal(_drew: bool):
	busy = true
	revealed = false
	refresh()
	animation = create_tween()
	animation.tween_interval(0.35)
	animation.tween_callback(func():
		if not opened: return
		revealed = true
		busy = false
		refresh())

func show_rules():
	rules_mode = true
	modal_text.text = "九点 · 2—4人\n\n每人先拿一张，可停牌或再摸一张。\n按住鼠标或手指擦开牌面；也可直接翻开。\nA为1，2—9按牌面，10/J/Q/K为0。相加取个位，9点最大。\n\n最高点赢奖池，并列平分；整数零钱随机分给并列赢家。\n\n时间与巡逻继续运行。发牌后离桌或被打断视为弃局。"
	modal_yes.text = "知道了"
	modal_no.hide()
	scratch.pointer = -2
	scratch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.show()
	modal_yes.grab_focus()

func show_forfeit():
	rules_mode = false
	modal_text.text = "离开牌桌？\n\n本局已押 %d。\n离桌视为弃局，押注不能退回。\n其他牌友将完成本局并分配奖池。\n\n外面的时间仍在继续。" % controller.round_model.stake
	modal_yes.text = "弃局离桌"
	modal_no.show()
	scratch.pointer = -2
	scratch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.show()
	modal_no.grab_focus()

func _hide_modal():
	modal.hide()
	scratch.mouse_filter = Control.MOUSE_FILTER_STOP
	primary.grab_focus()

func _modal_yes():
	_hide_modal()
	if not rules_mode: controller.close()

func _input(event: InputEvent):
	if not opened or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if modal.visible: _hide_modal()
		else: controller.request_close()
	elif not modal.visible and event.keycode == KEY_E: _primary()
	elif not modal.visible and event.keycode == KEY_SPACE: _secondary()
	elif not modal.visible and controller.round_model.state == "betting" and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		controller.amount = Rules.STAKES[event.keycode-KEY_1+1]
		refresh()
	elif event.keycode in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: return
	get_viewport().set_input_as_handled()

func paint(canvas: CanvasItem):
	if not opened: return
	paint_count += 1
	Art.plate(canvas,Rect2(Vector2.ZERO,DESIGN))
	var model = controller.round_model
	var betting: bool = model.state == "betting"
	var scratching := scratch_index >= 0
	var heading := "九点 · 入座" if betting else "擦开第一张" if scratch_index == 0 else "擦开第二张" if scratch_index == 1 else "本局结果" if revealed else "你的手牌"
	Art.text(canvas,FONT,heading,Rect2(12,12,396,34),27)
	var pot: int = controller.player_count*controller.amount if betting else model.pot
	Art.text(canvas,FONT,"%d人牌局    %s %d" % [controller.player_count,"预计奖池" if betting else "奖池",pot],Rect2(14,52,392,30),21)
	if betting:
		Art.text(canvas,FONT,"每人押注 · 全员同额",Rect2(14,150,392,30),22)
		Art.text(canvas,FONT,"余额 %d" % controller.game.inventory.wallet,Rect2(14,248,392,30),23)
		Art.text(canvas,FONT,controller.bet_reason(),Rect2(14,290,392,45),17,Color("9c493a"))
	else:
		if scratching:
			if scratch_index == 1: Art.card(canvas,FONT,Rect2(42,145,114,156),int(model.hands[0][0]))
			Art.text(canvas,FONT,"点数待揭晓 · 按住拖动擦开",Rect2(14,320,392,30),21)
		else:
			for i in 2:
				Art.card(canvas,FONT,Rect2(65+i*170,102,120,166),int(model.hands[0][i]) if i < known_cards else -1,i >= model.hands[0].size())
			Art.text(canvas,FONT,"当前 %d 点" % Rules.points(model.hands[0].slice(0,known_cards)),Rect2(14,280,392,32),25)
			Art.text(canvas,FONT,model.result_text() if revealed else "最多两张，相加只取个位",Rect2(14,318,392,30),19)
