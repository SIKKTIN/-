@tool
extends RefCounted

static func style(fill: String, border := "b7b9aa", padding := 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(fill)
	box.border_color = Color(border)
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(padding)
	return box

static func make() -> Theme:
	var result: Theme = load("res://art/ui/fullscreen/theme.tres").duplicate(true)
	result.default_font_size = 13
	for type in ["Button","OptionButton","CheckButton","CheckBox"]:
		result.set_stylebox("normal",type,style("f6f2e7"))
		result.set_stylebox("hover",type,style("e4eee6","438c83"))
		result.set_stylebox("pressed",type,style("217f79","217f79"))
		result.set_stylebox("disabled",type,style("e8e5db","d1d1c5"))
		result.set_color("font_color",type,Color("2e4147"))
		result.set_color("font_pressed_color",type,Color("ffffff"))
		result.set_color("font_disabled_color",type,Color("92978b"))
	result.set_stylebox("panel","PanelContainer",style("f1eddf","b7b9aa",6))
	result.set_stylebox("normal","LineEdit",style("faf6eb"))
	result.set_stylebox("focus","LineEdit",style("faf6eb","217f79"))
	result.set_color("font_color","LineEdit",Color("2e4147"))
	result.set_color("font_placeholder_color","LineEdit",Color("849086"))
	result.set_color("font_uneditable_color","LineEdit",Color("718079"))
	result.set_stylebox("read_only","LineEdit",style("e8e6dc"))
	result.set_stylebox("pressed","CheckBox",style("f1eddf","f1eddf",3))
	result.set_stylebox("normal","CheckBox",style("f1eddf","f1eddf",3))
	result.set_color("font_pressed_color","CheckBox",Color("2e4147"))
	result.set_stylebox("panel","ItemList",style("f4efe2","c6c5b8",4))
	result.set_stylebox("selected","ItemList",style("d1e5dc","217f79"))
	result.set_stylebox("selected_focus","ItemList",style("d1e5dc","217f79"))
	result.set_color("font_color","ItemList",Color("2e4147"))
	result.set_color("font_selected_color","ItemList",Color("174c49"))
	result.set_stylebox("panel","TabContainer",style("f1eddf","c6c5b8",6))
	for state in ["tab_selected","tab_unselected","tab_hovered"]:
		result.set_stylebox(state,"TabContainer",style("217f79" if state=="tab_selected" else "e4e0d3","b7b9aa",8))
		result.set_stylebox(state,"TabBar",result.get_stylebox(state,"TabContainer"))
	for type in ["TabContainer","TabBar"]:
		result.set_color("font_selected_color",type,Color.WHITE)
		result.set_color("font_unselected_color",type,Color("596861"))
	return result
