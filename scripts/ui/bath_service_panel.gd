extends Node

const Art=preload("res://scripts/ui/looting_skin.gd")
var service
var game
var panel: Panel
var blocker: ColorRect
var summary: Label
var note: Label
var choices: OptionButton
var buttons: Array[Button]=[]
var actor_id: int=-1
var selected_card: String=""
var listed_cards: Array=[]
var choice_key: Array=[]
var notice: String=""
var progress_panel: Panel
var progress_label: Label
var progress: ProgressBar
var effect_nodes: Dictionary={}

func configure(owner_service):
	service=owner_service;game=service.game
	blocker=ColorRect.new()
	blocker.name="WaterCardBlocker";blocker.color=Color(0.02,0.04,0.04,0.45);blocker.z_index=110
	game.get_node("HUD").add_child(blocker)
	panel=Panel.new()
	panel.name="WaterCardRecharge";panel.z_index=111
	panel.theme=load("res://art/ui/fullscreen/theme.tres")
	panel.add_theme_stylebox_override("panel",Art.box(Color("eee8d7"),Color("667d7b"),8,18))
	game.get_node("HUD").add_child(panel)
	var column:=VBoxContainer.new()
	column.name="Content"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left=20;column.offset_right=-20;column.offset_top=18;column.offset_bottom=-18
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	var portrait:=TextureRect.new()
	portrait.texture=preload("res://scripts/presentation/character_library.gd").portrait("bath_cashier")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size=Vector2(72,72);heading.add_child(portrait)
	var title:=make_label(heading,"水卡充值",25)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close_button:=make_button(heading,"×",close,false)
	close_button.custom_minimum_size=Vector2(42,42)
	summary=make_label(column,"",18);summary.name="BalanceSummary"
	choices=OptionButton.new()
	choices.name="CardChoice";choices.custom_minimum_size.y=40
	choices.item_selected.connect(func(index):selected_card=str(listed_cards[index]);refresh())
	column.add_child(choices)
	make_label(column,"1元充值1点 · 每次洗澡%d点" % service.cost(),16)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",12);column.add_child(row)
	for value in service.config.get("recharge_amounts",[5,10,20]):
		var amount:=int(value)
		var button:=make_button(row,"充值%d元" % amount,transact.bind(amount),true)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=48
		button.set_meta("amount",amount);buttons.append(button)
	note=make_label(column,"",15);note.name="RechargeNotice";note.custom_minimum_size.y=60
	make_label(column,"首次充值免费领卡，占1格；充值期间时间继续。",14)
	progress_panel=Panel.new()
	progress_panel.name="BathProgress";progress_panel.z_index=45
	progress_panel.theme=panel.theme;progress_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress_panel.add_theme_stylebox_override("panel",Art.box(Color("eee8d7"),Color("667d7b"),7,8))
	game.get_node("HUD").add_child(progress_panel)
	progress_label=Label.new()
	progress_label.position=Vector2(12,8);progress_label.add_theme_font_size_override("font_size",16)
	progress_panel.add_child(progress_label)
	progress=ProgressBar.new()
	progress.position=Vector2(12,38);progress.size=Vector2(396,9);progress.show_percentage=false
	progress.add_theme_stylebox_override("background",Art.box(Color("bfc6ba"),Color.TRANSPARENT,4,0))
	progress.add_theme_stylebox_override("fill",Art.box(Art.TEAL,Color.TRANSPARENT,4,0))
	progress_panel.add_child(progress)
	game.get_viewport().size_changed.connect(layout)
	close();layout();refresh_progress()

func make_label(parent: Node,text: String,font_size: int) -> Label:
	var label:=Label.new()
	label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Art.INK)
	parent.add_child(label);return label

func make_button(parent: Node,text: String,callback: Callable,primary: bool) -> Button:
	var button:=Button.new()
	button.text=text;button.focus_mode=Control.FOCUS_NONE
	Art.style_button(button,primary);button.pressed.connect(callback);parent.add_child(button)
	return button

func is_open() -> bool:return panel!=null and panel.visible

func open(id: int):
	actor_id=id;selected_card=service.preferred_card(id);notice=""
	panel.show();blocker.show();layout();refresh()

func close():
	if panel:panel.hide()
	if blocker:blocker.hide()
	actor_id=-1;selected_card="";listed_cards=[];choice_key=[]

func layout():
	var view: Vector2=game.get_viewport_rect().size
	blocker.position=Vector2.ZERO;blocker.size=view
	panel.size=Vector2(minf(540,view.x-24),minf(420,view.y-24));panel.position=(view-panel.size)/2
	progress_panel.size=Vector2(420,58);progress_panel.position=Vector2((view.x-420)/2,view.y-140)

func refresh():
	if not is_open():return
	var cards: Array=service.card_ids(actor_id)
	if not cards.has(selected_card):selected_card=service.preferred_card(actor_id)
	var key: Array=[cards.duplicate(),selected_card]
	for card in cards:key.append(service.balance(str(card)))
	if key!=choice_key:
		choice_key=key;choices.clear();listed_cards=cards.duplicate();choices.visible=cards.size()>1
		for i in range(cards.size()):
			choices.add_item("水卡%d · 余额%d点" % [i+1,service.balance(cards[i])])
			if str(cards[i])==selected_card:choices.select(i)
	summary.text="现金 %d元   ·   %s" % [game.inventory.wallet,"尚无水卡" if selected_card.is_empty() else "水卡余额 %d点" % service.balance(selected_card)]
	note.text=notice if not notice.is_empty() else ("充值时会领取一张新水卡。" if cards.is_empty() else "充值到当前选择的水卡，余额随卡保留。")
	for button in buttons:
		var poor: bool=game.inventory.wallet<int(button.get_meta("amount"))
		var full: bool=cards.is_empty() and game.inventory.find_space(actor_id,"water_card").x<0
		button.disabled=poor or full
		button.tooltip_text="现金不足。" if poor else "背包需要1个空格领卡。" if full else ""

func transact(amount: int):
	var result: Dictionary=service.try_recharge(actor_id,amount,selected_card)
	notice=str(result.reason)
	if result.ok:selected_card=str(result.card_id)
	game.show_status(notice,5);game._update_ui();refresh()

func refresh_progress():
	if not progress_panel:return
	var id: int=game.selected_actor_id
	progress_panel.visible=service.sessions.has(id)
	if progress_panel.visible:
		var session: Dictionary=service.sessions[id]
		progress_label.text="洗澡中 · %.1f秒 · 移动或E取消并退款" % maxf(0,float(session.duration)-float(session.elapsed))
		progress.value=100*float(session.elapsed)/float(session.duration)
	for key in effect_nodes.keys():
		if not service.sessions.has(key):effect_nodes[key].queue_free();effect_nodes.erase(key)
	for key in service.sessions:
		if not effect_nodes.has(key):
			var added:=ShowerEffect.new();game.add_child(added);effect_nodes[key]=added
		var session: Dictionary=service.sessions[key]
		var effect=effect_nodes[key]
		effect.position=service.station_point(str(session.station_id))
		effect.z_index=preload("res://scripts/presentation/world_depth.gd").for_y(effect.position.y,game.world.bounds.end.y)+1
		effect.phase=float(session.elapsed);effect.mirrored=service.stations[session.station_id].get("mirror_x",false)
		effect.visible=not game.world.is_under_roof(effect.position);effect.queue_redraw()

func _input(event: InputEvent):
	if is_open() and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close();game.get_viewport().set_input_as_handled()

class ShowerEffect extends Node2D:
	var phase:=0.0
	var mirrored:=false
	func _draw():
		var sign_x: float=1 if mirrored else -1
		for i in range(18):
			var offset:=Vector2(sign_x*(32+i*0.7),-111)
			var t:=fposmod(phase*1.8+i*.087,1)
			var point:=offset+Vector2(-sign_x*18,93)*t
			draw_line(point,point+Vector2(-sign_x*1.5,7),Color(0.7,0.88,0.92,0.65),1.2,true)
		draw_arc(Vector2(sign_x*22,-6),8+fposmod(phase,1)*10,0,PI,18,Color(0.66,0.88,0.9,0.3),1,true)
