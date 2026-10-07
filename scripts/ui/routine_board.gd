extends Control

const TIMES := ["08:00–12:00", "12:00–14:00", "14:00–18:00", "18:00–20:00", "20:00–24:00"]
const PHASES := ["劳动", "吃饭休息", "劳动", "自由活动", "寝室区自由"]
var ui

static func draw_activity_icon(canvas: CanvasItem, kind: String, p: Vector2, ink: Color) -> void:
	match kind:
		"meal":
			canvas.draw_arc(p+Vector2(0,-1),9,0,PI,16,ink,3,true)
			canvas.draw_line(p+Vector2(-10,1),p+Vector2(10,1),ink,2,true)
			canvas.draw_line(p+Vector2(-5,-11),p+Vector2(-4,-5),ink,2,true)
			canvas.draw_line(p+Vector2(4,-11),p+Vector2(5,-5),ink,2,true)
		"work":
			canvas.draw_line(p+Vector2(-7,9), p+Vector2(6,-5), ink, 5, true)
			canvas.draw_line(p+Vector2(0,-10), p+Vector2(11,0), ink, 8, true)
		"rest":
			canvas.draw_line(p+Vector2(-11,-8), p+Vector2(-11,10), ink, 3, true)
			canvas.draw_line(p+Vector2(11,-3), p+Vector2(11,10), ink, 3, true)
			canvas.draw_rect(Rect2(p+Vector2(-10,-2), Vector2(21,8)), ink)
			canvas.draw_circle(p+Vector2(-6,-6), 3, ink, true, -1, true)
		"free":
			canvas.draw_circle(p+Vector2(1,-10), 3, ink, true, -1, true)
			for pair in [[Vector2(0,-4),Vector2(-2,4)], [Vector2(0,-4),Vector2(8,0)], [Vector2(0,-3),Vector2(-8,0)], [Vector2(-2,4),Vector2(-7,12)], [Vector2(-2,4),Vector2(5,11)]]:
				canvas.draw_line(p+pair[0], p+pair[1], ink, 3, true)
		_:
			canvas.draw_circle(p+Vector2(0,-7), 4, ink, true, -1, true)
			canvas.draw_style_box(_round_box(ink, 4), Rect2(p+Vector2(-8,0), Vector2(16,12)))

static func _round_box(color: Color, radius: int, selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if selected:
		style.border_color = Color("328b82")
		style.set_border_width_all(2)
	return style

func _draw() -> void:
	if not ui or ui.row_rects.is_empty():
		return
	var ink := Color("303b46")
	var muted := Color("727d70")
	var font: Font = ui.game.presentation.font
	var pad: float = ui.pad
	var divider: float = ui.timeline_y-16
	draw_line(Vector2(pad, divider), Vector2(size.x-pad, divider), Color("d3cdbc"), 1, true)
	var day_rect := Rect2(ui.day_label.position-Vector2(10, 3), Vector2(90,36))
	draw_style_box(_round_box(Color("e9dfc5"), 5), day_rect)
	var clock_p: Vector2 = ui.clock_label.position+Vector2(-18, 15)
	draw_circle(clock_p, 12, ink, false, 2, true)
	draw_line(clock_p, clock_p+Vector2(0,-8), ink, 2, true)
	draw_line(clock_p, clock_p+Vector2(6,4), ink, 2, true)
	# Quiet paper seams and a small clip echo the approved planner concept.
	draw_rect(Rect2(18,-6,22,13), Color("687469"), false, 2)
	draw_line(Vector2(22,8), Vector2(35,8), Color("9e9e88"), 2, true)
	var time_size := 15 if ui.column_width < 178 else 18
	for index in range(5):
		var center: float = ui.activity_left+ui.column_width*(index+0.5)
		_center_text(font, Vector2(center,ui.timeline_y+19), TIMES[index], time_size, ink)
		_center_text(font, Vector2(center,ui.timeline_y+43), PHASES[index], 16, ink)
	draw_line(Vector2(ui.activity_left,ui.rule_y), Vector2(size.x-pad,ui.rule_y), Color("9ea694"), 2, true)
	for index in range(6):
		draw_circle(Vector2(ui.activity_left+index*ui.column_width,ui.rule_y),3,muted,true,-1,true)
	var minute: float = ui.game.schedule.clock_minutes()
	var slot: int = ui.game.routines.current_slot()
	if slot >= 0:
		var interval = ui.game.routines.SLOTS[slot]
		var fraction: float = (minute-interval.start)/(interval.end-interval.start)
		var point := Vector2(ui.activity_left+(slot+fraction)*ui.column_width, ui.rule_y)
		draw_circle(point,6,Color("d3a252"),true,-1,true)
		draw_circle(point,6,Color("a47a3c"),false,2,true)
	for id in range(3):
		var rect: Rect2 = ui.row_rects[id]
		draw_style_box(_round_box(Color("eee8db"), 12), rect)
		var selected: bool = id == ui.editing_actor
		if selected:
			draw_style_box(_round_box(Color("e5f0e9"), 12, true), Rect2(rect.position, Vector2(ui.activity_left-pad-6,rect.size.y)))
		var portrait: Texture2D = ui.portraits[id]
		var area := Rect2(rect.position+Vector2(6,4), Vector2(62,rect.size.y-8))
		if portrait:
			var fitted := portrait.get_size()*minf(area.size.x/portrait.get_width(),area.size.y/portrait.get_height())
			draw_texture_rect(portrait,Rect2(area.position+(area.size-fitted)/2,fitted),false)
		var badge := Rect2(rect.position+Vector2(78,13),Vector2(25,26))
		draw_style_box(_round_box(Color("328b82") if selected else muted,5),badge)
		_center_text(font, badge.position+Vector2(12.5,21), str(id+1), 18, Color("fffdf5"))
		draw_string(font, rect.position+Vector2(78,61), "已逃脱" if ui.game.actors[id].escaped else "主角" if ui.game.actor_is_controllable(id) else "自动囚徒", HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	var x: float = pad+22
	for kind in ui.KINDS:
		if kind == "meal" and not ui.game.routines.has_cafeteria():
			continue
		draw_activity_icon(self,kind,Vector2(x,ui.legend_y+12),ink)
		draw_string(font,Vector2(x+22,ui.legend_y+18),ui.game.routines.NAMES[kind],HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
		x += 105 if ui.game.routines.has_cafeteria() else 130 if kind != "free" else 140
	var night := "00:00–08:00  自动睡觉与查寝"
	var width := font.get_string_size(night,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(font,Vector2(size.x-pad-width,ui.legend_y+18),night,HORIZONTAL_ALIGNMENT_LEFT,-1,14,muted)
	draw_line(Vector2(pad,ui.note.position.y-8),Vector2(size.x-pad,ui.note.position.y-8),Color("d3cdbc"),1,true)

func _center_text(font: Font, point: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(font,point-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
