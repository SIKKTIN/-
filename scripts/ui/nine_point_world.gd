extends Node2D

const Seating = preload("res://scripts/ui/nine_point_seating.gd")
const Art = preload("res://scripts/ui/nine_point_art.gd")
const Rules = preload("res://scripts/minigames/nine_point_round.gd")
const FONT = preload("res://art/fonts/NotoSansCJKsc-Regular.otf")
const CHAIRS := [
	[Vector2(723,736),Vector2(875,736),Vector2(889,840),Vector2(881,893),Vector2(718,893),Vector2(708,840)],
	[Vector2(719,74),Vector2(878,74),Vector2(877,176),Vector2(720,176)],
	[Vector2(315,324),Vector2(393,344),Vector2(385,534),Vector2(333,540),Vector2(294,476)],
	[Vector2(1207,348),Vector2(1281,324),Vector2(1307,481),Vector2(1270,538),Vector2(1217,530)]
]
var controller
var area := Rect2()
var labels: Node2D

class SeatLabels extends Node2D:
	var owner_view
	func _draw(): owner_view.paint_labels(self)

func _ready():
	labels = SeatLabels.new()
	labels.owner_view = self
	labels.z_as_relative = false
	labels.z_index = 2001
	add_child(labels)

func setup(owner_controller, table_area: Rect2):
	controller = owner_controller
	area = Rect2(table_area.position-Vector2(0,30),table_area.size)
	z_index = preload("res://scripts/presentation/world_depth.gd").for_y(area.end.y+55,controller.game.world.bounds.end.y)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func seats() -> Array:
	return [Vector2(area.get_center().x,area.end.y+28),Vector2(area.get_center().x,area.position.y+2),Vector2(area.position.x-20,area.get_center().y+5),Vector2(area.end.x+20,area.get_center().y+5)]

func chair(index: int, foreground := false):
	var pieces: Array = CHAIRS[index]
	if foreground:
		if index == 0: pieces = Seating.SOUTH_BACK
		elif index == 2: pieces = Seating.WEST_FRONT
		elif index == 3: pieces = Seating.EAST_FRONT
		else: return
	draw_set_transform(seats()[index]-Seating.SEATS[index]*0.27,0,Vector2.ONE*0.27)
	Seating.artwork_piece(self,controller.panel.background,pieces)
	draw_set_transform(Vector2.ZERO)

func actor(index: int, upper_only := false):
	var texture: Texture2D = controller.panel.poses[Seating.IDS[index]][Seating.VIEWS[index]]
	var dimensions := texture.get_size()*(58.0/texture.get_height())
	var hip: Vector2 = Seating.HIPS[index]
	if index == 3: hip.x = 1.0-hip.x
	var point: Vector2 = seats()[index]-dimensions*hip
	var fraction := 0.73 if upper_only else 1.0
	draw_set_transform(point+Vector2(dimensions.x,0) if index == 3 else point,0,Vector2(-1,1) if index == 3 else Vector2.ONE)
	draw_texture_rect_region(texture,Rect2(Vector2.ZERO,dimensions*Vector2(1,fraction)),Rect2(Vector2.ZERO,texture.get_size()*Vector2(1,fraction)))
	draw_set_transform(Vector2.ZERO)

func _draw():
	if not controller or not controller.is_open() or controller.panel.background == null: return
	var count: int = controller.player_count if controller.round_model.state == "betting" else controller.round_model.names.size()
	for index in count: chair(index)
	for index in range(1,count): actor(index)
	var table_scale := area.size/Vector2(864,559)
	draw_set_transform(area.position-Vector2(369,176)*table_scale,0,table_scale)
	Seating.artwork_piece(self,controller.panel.background,Seating.TABLE)
	draw_set_transform(Vector2.ZERO)
	for index in range(1,count): actor(index,true); chair(index,true)
	actor(0)
	chair(0,true)
	var model = controller.round_model
	var offsets := [Vector2(-12,25),Vector2(-12,-42),Vector2(-52,-6),Vector2(38,-6)]
	for index in count:
		var card_count: int = 0 if model.state == "betting" else model.hands[index].size()
		for j in card_count:
			var value: int = model.hands[index][j] if controller.panel.revealed or index == 0 and j < controller.panel.known_cards else -1
			draw_set_transform(area.get_center()+offsets[index]+Vector2(j*15,0),0,Vector2.ONE*0.16)
			Art.card(self,FONT,Rect2(0,0,78,106),value)
			draw_set_transform(Vector2.ZERO)
	for i in 5:
		draw_circle(area.get_center()+Vector2((i%3)*6-6,(i/3)*5-3),3.5,Color("ca9b53"))
	labels.queue_redraw()

func paint_labels(canvas: CanvasItem):
	if not controller or not controller.is_open(): return
	var model = controller.round_model
	var count: int = controller.player_count if model.state == "betting" else model.names.size()
	var locations := [seats()[0]+Vector2(-80,34),seats()[1]+Vector2(36,-30),seats()[2]+Vector2(-50,-88),seats()[3]+Vector2(25,-5)]
	for i in count:
		var label := Rect2(locations[i],Vector2(80,39))
		Art.plate(canvas,label,"selected" if controller.panel.revealed and i in model.winners else "paper")
		Art.text(canvas,FONT,controller.NAMES[i],Rect2(label.position,Vector2(80,20)),14)
		var caption := "%d点" % Rules.points(model.hands[i]) if controller.panel.revealed else "押%d" % (controller.amount if model.state == "betting" else model.stake)
		Art.text(canvas,FONT,caption,Rect2(label.position+Vector2(0,19),Vector2(80,19)),12)
