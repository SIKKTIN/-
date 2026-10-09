extends Control

var ui
var portrait_frame: StyleBoxFlat
var compact := false

func configure(owner_ui):
	ui = owner_ui
	name = "PlayerResponses"
	z_index = 150
	theme = ui.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame = StyleBoxFlat.new()
	portrait_frame.bg_color = Color("f2ebdd")
	portrait_frame.border_color = Color("68796c")
	portrait_frame.set_border_width_all(2)
	portrait_frame.set_corner_radius_all(7)
	portrait_frame.shadow_color = Color(0,0,0,0.2)
	portrait_frame.shadow_size = 3
	resized.connect(queue_redraw)
	hide()

func _draw():
	var area := Rect2(0,0,36 if compact else 42,36 if compact else 44)
	draw_style_box(portrait_frame,area)
	var portrait: Texture2D = ui.portraits[ui.game.PLAYER_ACTOR_ID]
	if portrait:
		var fitted: Vector2 = portrait.get_size()*minf((area.size.x-6)/portrait.get_width(),(area.size.y-6)/portrait.get_height())
		draw_texture_rect(portrait,Rect2(area.get_center()-fitted/2,fitted),false)
	var baseline := Vector2(area.end.x+14,27 if compact else 31)
	var font_size := 18 if compact else 20
	draw_string_outline(ui.font,baseline,"你的回应",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0.1,0.16,0.16,0.75))
	draw_string(ui.font,baseline,"你的回应",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff9ed"))
