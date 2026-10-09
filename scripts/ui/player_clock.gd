extends Button

const HudArt = preload("res://scripts/ui/hud_skin.gd")
var ui

func _draw():
	if not ui: return
	var schedule = ui.game.schedule
	var minute: float = schedule.clock_minutes()
	var tutorial: bool = ui.game.tutorial!=null and ui.game.tutorial.active
	var alarm: bool = ui.game.prison_alert.active
	var danger: bool = alarm or schedule.is_curfew() or schedule.real_remaining()<=30
	var ink := Color("b65447") if danger else HudArt.INK
	var split := floorf(size.x*0.55)
	draw_circle(Vector2(28,29),13,HudArt.INK,false,2,true)
	draw_line(Vector2(28,29),Vector2(28,19),HudArt.INK,2,true)
	draw_line(Vector2(28,29),Vector2(36,34),HudArt.INK,2,true)
	draw_string(ui.font,Vector2(51,39),"%02d:%02d" % [floori(minute/60),floori(minute)%60],HORIZONTAL_ALIGNMENT_LEFT,-1,27,ink)
	var stage: String = "全员警戒" if alarm else schedule.config.stages[schedule.stage_index].name
	var stage_size := 16
	while ui.font.get_string_size(stage,HORIZONTAL_ALIGNMENT_LEFT,-1,stage_size).x>split-155 and stage.length()>3: stage = stage.left(stage.length()-2)+"…"
	draw_string(ui.font,Vector2(144,38),stage,HORIZONTAL_ALIGNMENT_LEFT,-1,stage_size,ink)
	draw_string(ui.font,Vector2(20,83),"第%d天 · %s" % [schedule.day_number(),"入监日" if tutorial else "正式逃脱"],HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	draw_line(Vector2(split,17),Vector2(split,size.y-17),Color("b9b4a4"),1,true)
	var start := Vector2(split+20,30)
	var length := size.x-split-40
	draw_line(start,start+Vector2(length,0),Color("a9ad9d"),4,true)
	draw_line(start,start+Vector2(length*minute/1440,0),Color("c49c5f"),4,true)
	for hour in [8,12,18,24]:
		var point := start+Vector2(length*hour/24.0,0)
		draw_circle(point,3,Color("718175"),true,-1,true)
		draw_string(ui.font,point+Vector2(-8,21),str(hour),HORIZONTAL_ALIGNMENT_LEFT,-1,12,HudArt.INK)
	var current := start+Vector2(length*minute/1440,0)
	draw_circle(current,6,HudArt.PAPER,true,-1,true)
	draw_circle(current,6,Color("c49c5f"),false,2,true)
	draw_string(ui.font,Vector2(split+20,83),"期限未开始" if tutorial else schedule.time_left_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	HudArt.rivets(self,size)
