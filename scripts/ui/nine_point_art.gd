extends RefCounted

const HudArt = preload("res://scripts/ui/hud_skin.gd")
const Rules = preload("res://scripts/minigames/nine_point_round.gd")
const INK := Color("303b46")
const PAPER := Color("eee6d5")
const SUITS := ["♠", "♥", "♣", "♦"]

static func text(canvas: CanvasItem, font: Font, value: String, rect: Rect2, font_size := 22, color := INK):
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, rect.position+Vector2(maxf(0,(rect.size.x-width)/2),rect.size.y*0.5+font_size*0.36), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, color)

static func plate(canvas: CanvasItem, rect: Rect2, kind := "paper"):
	canvas.draw_style_box(HudArt.box(kind),rect)
	for p in [rect.position+Vector2(8,8),Vector2(rect.end.x-8,rect.position.y+8),rect.end-Vector2(8,8),Vector2(rect.position.x+8,rect.end.y-8)]:
		canvas.draw_circle(p,3,Color("565d55"),true,-1,true)
		canvas.draw_circle(p-Vector2(0.5,0.5),1.8,Color("b8b7a7"),true,-1,true)

static func card(canvas: CanvasItem, font: Font, rect: Rect2, value := -1, empty := false):
	if empty:
		canvas.draw_dashed_line(rect.position,Vector2(rect.end.x,rect.position.y),PAPER,1.5,7)
		canvas.draw_dashed_line(Vector2(rect.end.x,rect.position.y),rect.end,PAPER,1.5,7)
		canvas.draw_dashed_line(rect.end,Vector2(rect.position.x,rect.end.y),PAPER,1.5,7)
		canvas.draw_dashed_line(Vector2(rect.position.x,rect.end.y),rect.position,PAPER,1.5,7)
		return
	canvas.draw_style_box(HudArt.box("paper"),rect)
	if value < 0:
		var inset := rect.grow(-6)
		canvas.draw_rect(inset,Color("365267"))
		for y in range(0,int(inset.size.y),10):
			for x in range(0,int(inset.size.x),10):
				if (x/10+y/10) % 2 == 0:
					canvas.draw_rect(Rect2(inset.position+Vector2(x,y),Vector2(minf(10,inset.size.x-x),minf(10,inset.size.y-y))),Color("6c899b"))
		return
	var suit: String = str(SUITS[value/13])
	var ink := Color("ad3c2c") if value/13 in [1,3] else INK
	text(canvas,font,Rules.card_label(value)+suit,Rect2(rect.position+Vector2(5,5),Vector2(rect.size.x-10,22)),18,ink)
	text(canvas,font,suit,Rect2(rect.position+Vector2(0,28),Vector2(rect.size.x,rect.size.y-54)),36,ink)
	text(canvas,font,Rules.card_label(value)+suit,Rect2(Vector2(rect.position.x+5,rect.end.y-27),Vector2(rect.size.x-10,22)),18,ink)
