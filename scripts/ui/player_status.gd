extends Control

const HudArt = preload("res://scripts/ui/hud_skin.gd")
var ui
var index := 0

func _draw():
	if index!=0: return
	var portrait: Texture2D = ui.portraits[0]
	var area := Rect2(12,10,64,82)
	draw_style_box(HudArt.box("inset"),area)
	if portrait:
		var fitted: Vector2 = portrait.get_size()*minf((area.size.x-8)/portrait.get_width(),(area.size.y-8)/portrait.get_height())
		draw_texture_rect(portrait,Rect2(area.get_center()-fitted/2,fitted),false)
	var values: Dictionary = ui.game.attributes.values[0]
	for row in range(2):
		var value: float = values.stamina if row==0 else values.fullness
		var y := 23.0+row*27
		draw_string(ui.font,Vector2(86,y+7),"体力" if row==0 else "饱腹",HORIZONTAL_ALIGNMENT_LEFT,-1,15,HudArt.INK)
		var bar := Rect2(124,y-5,size.x-168,12)
		draw_style_box(HudArt.box("inset"),bar)
		var color := Color("bf6653") if value<25 else HudArt.TEAL if row==0 else Color("7da399")
		draw_rect(Rect2(bar.position+Vector2(2,2),Vector2((bar.size.x-4)*clampf(value/100,0,1),8)),color)
		draw_string(ui.font,Vector2(size.x-36,y+7),str(roundi(value)),HORIZONTAL_ALIGNMENT_LEFT,-1,15,HudArt.INK)
	var actor = ui.game.actors[0]
	var icon: Texture2D = ui.inventory_drawer.icon_for("backpack") if actor.skill_id=="backpack" else ui.game.presentation.skill_icons.get(actor.skill_id)
	if icon: draw_texture_rect(icon,Rect2(86,76,18,20),false)
	draw_string(ui.font,Vector2(110,92),ui.game.SKILL_NAMES[actor.skill_id],HORIZONTAL_ALIGNMENT_LEFT,-1,14,HudArt.INK)
	var jailed: int = ui.game.confinement_counts[0]
	draw_string(ui.font,Vector2(size.x-89,92),"禁闭 %d/3" % jailed,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ba5847") if jailed>=2 else Color("8d794c"))
	HudArt.rivets(self,size)
