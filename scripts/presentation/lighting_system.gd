extends Node2D

const PaperBackdrop = preload("res://scripts/presentation/paper_backdrop.gd")

var game
var settings: Dictionary
var period: String = "day"
var ambient: CanvasModulate
var sun: DirectionalLight2D
var lamps: Array[PointLight2D] = []
var occluders: Array[LightOccluder2D] = []
var lamp_specs: Array = []
var room_id: String = ""
var obstacle_revision: int = -1
var toggle_button: Button

func configure(owner_game, theme: Theme) -> void:
	game = owner_game
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/lighting.json"))
	period = settings.default_period
	z_index = 1900
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	var paper := PaperBackdrop.new()
	paper.name = "PaperBackdrop"
	game.add_child(paper)
	ambient = CanvasModulate.new()
	ambient.name = "RoomAmbient"
	add_child(ambient)
	sun = DirectionalLight2D.new()
	sun.name = "Daylight"
	sun.color = Color(settings.sun_color)
	sun.energy = settings.sun_energy
	sun.shadow_enabled = false
	sun.range_layer_min = 0
	sun.range_layer_max = 0
	add_child(sun)
	toggle_button = Button.new()
	toggle_button.name = "ToggleDayNight"
	toggle_button.position = Vector2(1025,16)
	toggle_button.size = Vector2(155,38)
	toggle_button.theme = theme
	toggle_button.add_theme_font_size_override("font_size",16)
	toggle_button.tooltip_text = "切换昼夜照明（N）；当前只改变画面，狱警警戒规则保持一致。"
	toggle_button.pressed.connect(toggle_period)
	game.get_node("HUD").add_child(toggle_button)
	tick()
	set_period(period)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		toggle_period()
		get_viewport().set_input_as_handled()

func toggle_period() -> void:
	set_period("night" if period == "day" else "day")

func set_period(value: String) -> void:
	if value not in ["day","night"]:
		return
	period = value
	ambient.color = Color(settings.day_ambient if period == "day" else settings.night_ambient)
	sun.enabled = period == "day"
	for lamp in lamps:
		lamp.enabled = period == "night"
	if toggle_button:
		toggle_button.text = "白天 · 切换 N" if period == "day" else "夜晚 · 切换 N"
	queue_redraw()

func _light_texture(radius: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.20,0.62,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.8),Color(1,1,1,0.24),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = ceili(radius*2)
	texture.height = ceili(radius*2)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	return texture

func _rebuild_lamps() -> void:
	for lamp in lamps:
		lamp.free()
	lamps.clear()
	lamp_specs = settings.rooms.get(game.world.room_id,[])
	for index in range(lamp_specs.size()):
		var spec: Dictionary = lamp_specs[index]
		var lamp := PointLight2D.new()
		lamp.name = "RoomLamp%d" % (index+1)
		lamp.position = Vector2(spec.position[0],spec.position[1])
		lamp.texture = _light_texture(float(spec.radius))
		lamp.color = Color(settings.lamp_color)
		lamp.energy = settings.lamp_energy
		lamp.range_layer_min = 0
		lamp.range_layer_max = 0
		lamp.shadow_enabled = true
		lamp.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		lamp.shadow_filter_smooth = 1.5
		lamp.enabled = period == "night"
		add_child(lamp)
		lamps.append(lamp)
	queue_redraw()

func _sync_occluders() -> void:
	var solids: Array = game.world.solid_rects()
	while occluders.size() > solids.size():
		occluders.pop_back().free()
	while occluders.size() < solids.size():
		var node := LightOccluder2D.new()
		node.name = "RoomOccluder%d" % occluders.size()
		node.occluder = OccluderPolygon2D.new()
		add_child(node)
		occluders.append(node)
	for index in range(solids.size()):
		var rect: Rect2 = solids[index]
		occluders[index].occluder.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	obstacle_revision = game.world.obstacle_revision

func tick() -> void:
	if room_id != game.world.room_id:
		room_id = game.world.room_id
		_rebuild_lamps()
		obstacle_revision = -1
	if obstacle_revision != game.world.obstacle_revision:
		_sync_occluders()

func _draw() -> void:
	for spec in lamp_specs:
		var point := Vector2(spec.position[0],spec.position[1])
		draw_line(point-Vector2(0,15),point,Color("515b5b"),3,true)
		draw_style_box(_fixture(),Rect2(point-Vector2(9,6),Vector2(18,12)))
		draw_circle(point,4,Color("ffe6af") if period == "night" else Color("b8b8a8"))
		if period == "night":
			draw_arc(point,8,0,TAU,24,Color(1,0.85,0.55,0.35),2,true)

func _fixture() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("65706d")
	box.border_color = Color("414b49")
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	return box

func snapshot() -> Dictionary:
	return {"version":settings.version,"period":period,"room":room_id,"ambient":ambient.color.to_html(),"sun_enabled":sun.enabled,"lamps":lamps.map(func(lamp): return {"position":[lamp.position.x,lamp.position.y],"enabled":lamp.enabled,"shadows":lamp.shadow_enabled,"energy":lamp.energy}),"occluder_count":occluders.size(),"obstacle_revision":obstacle_revision}
