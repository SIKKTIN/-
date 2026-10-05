extends Node2D

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
var guard_light: PointLight2D
var guard_boundaries: Array[LightOccluder2D] = []
var beam_texture: Texture2D
var curfew_beam_texture: Texture2D
var search_lights: Dictionary = {}

func configure(owner_game, theme: Theme) -> void:
	game = owner_game
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/lighting.json"))
	period = settings.default_period
	z_index = 1900
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
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
	sun.range_item_cull_mask = 3
	add_child(sun)
	toggle_button = Button.new()
	toggle_button.name = "ToggleDayNight"
	toggle_button.position = Vector2(1025,16)
	toggle_button.size = Vector2(155,38)
	toggle_button.theme = theme
	toggle_button.add_theme_font_size_override("font_size",16)
	toggle_button.tooltip_text = "日程决定昼夜；白天狱警看得更远，夜晚视野缩短。"
	game.get_node("HUD").add_child(toggle_button)
	guard_light = PointLight2D.new()
	guard_light.name = "GuardFlashlight"
	beam_texture = _beam_texture()
	curfew_beam_texture = _beam_texture(PI)
	guard_light.texture = beam_texture
	guard_light.shadow_enabled = true
	guard_light.shadow_item_cull_mask = 3
	guard_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	guard_light.shadow_filter_smooth = 0.8
	guard_light.range_layer_min = 0
	guard_light.range_layer_max = 0
	add_child(guard_light)
	tick()
	set_period(period)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N and game.schedule:
		game.schedule.toggle()
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
	_tick_guard_light()

func _beam_texture(half_angle: float = PI/3) -> ImageTexture:
	# A procedural light texture, not a modified art asset. +X is its direction.
	var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var offset := (Vector2(x+0.5,y+0.5)-Vector2(128,128))/128.0
			var radial := 1.0-smoothstep(0.65,1.0,offset.length())
			var angular := 1.0 if half_angle >= PI else 1.0-smoothstep(half_angle-0.025,half_angle,absf(offset.angle()))
			image.set_pixel(x,y,Color(1,1,1,maxf(0,radial*angular)))
	return ImageTexture.create_from_image(image)

func _tick_guard_light() -> void:
	if not guard_light:
		return
	# Boundary occluders track the midnight inspection permission.
	if not guard_boundaries.is_empty():
		var zone: Rect2 = game.guard.search_zone()
		if guard_boundaries[0].occluder.polygon[0] != zone.position:
			_sync_guard_boundaries()
	guard_light.position = game.guard.position
	var desired: Texture2D = curfew_beam_texture if game.guard.curfew_alert() else beam_texture
	if guard_light.texture != desired:
		guard_light.texture = desired
	guard_light.rotation = 0 if game.guard.curfew_alert() else game.guard.facing.angle()
	guard_light.texture_scale = game.guard.view_radius()/128.0
	guard_light.color = Color("ff9a74") if game.guard.state == "chasing" or game.guard.curfew_alert() else Color("ffe5b2")
	guard_light.energy = 0.65 if period == "night" else 0.26
	guard_light.enabled = game.phase == "playing" and game.guard.search_zone().has_point(game.guard.position)
	var team: Array = game.prison_alert.officers().slice(1) if game.prison_alert != null and game.prison_alert.active else []
	var ids: Array = team.map(func(g): return g.get_instance_id())
	for id in search_lights.keys():
		if id not in ids:
			search_lights[id].free()
			search_lights.erase(id)
	for officer in team:
		var id: int = officer.get_instance_id()
		if not search_lights.has(id):
			var light: PointLight2D = guard_light.duplicate()
			light.name = "SearchFlashlight%d" % id
			add_child(light)
			search_lights[id] = light
		var light: PointLight2D = search_lights[id]
		light.position = officer.position
		light.texture = curfew_beam_texture
		light.rotation = 0
		light.texture_scale = officer.view_radius()/128.0
		light.color = Color("ff9a74")
		light.energy = guard_light.energy
		light.enabled = game.phase == "playing" and officer.visible

func _sync_guard_boundaries() -> void:
	for node in guard_boundaries:
		node.free()
	guard_boundaries.clear()
	var zone: Rect2 = game.guard.search_zone()
	var edges := [
		PackedVector2Array([zone.position,Vector2(zone.end.x,zone.position.y)]),
		PackedVector2Array([Vector2(zone.end.x,zone.position.y),zone.end]),
		PackedVector2Array([zone.end,Vector2(zone.position.x,zone.end.y)]),
		PackedVector2Array([Vector2(zone.position.x,zone.end.y),zone.position])
	]
	for edge in edges:
		var node := LightOccluder2D.new()
		node.occluder_light_mask = 2
		node.occluder = OccluderPolygon2D.new()
		node.occluder.closed = false
		node.occluder.polygon = edge
		add_child(node)
		guard_boundaries.append(node)

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
	lamp_specs = settings.rooms.get(game.world.room_id,game.room_config.get("lamps",[]))
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
		lamp.range_item_cull_mask = 3
		lamp.shadow_enabled = true
		lamp.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		lamp.shadow_filter_smooth = 1.5
		lamp.enabled = period == "night"
		add_child(lamp)
		lamps.append(lamp)
	queue_redraw()

func _sync_occluders() -> void:
	var solids: Array = game.world.sight_rects()
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
		_sync_guard_boundaries()
		obstacle_revision = -1
	if obstacle_revision != game.world.obstacle_revision:
		_sync_occluders()
	_tick_guard_light()

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
	return {"version":settings.version,"period":period,"room":room_id,"ambient":ambient.color.to_html(),"sun_enabled":sun.enabled,"lamps":lamps.map(func(lamp): return {"position":[lamp.position.x,lamp.position.y],"enabled":lamp.enabled,"shadows":lamp.shadow_enabled,"energy":lamp.energy}),"occluder_count":occluders.size(),"obstacle_revision":obstacle_revision,"flashlight_radius":game.guard.view_radius(),"flashlight_enabled":guard_light.enabled}
