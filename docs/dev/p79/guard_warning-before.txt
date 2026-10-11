extends Node2D

const WarningShader = preload("res://scripts/presentation/guard_warning.gdshader")
const MAX_BLOCKERS := 64
var officer
var shader_material: ShaderMaterial
var radius := -1.0
var blockers := PackedVector4Array()
var blocker_key: Array = []
var geometry_updates := 0
var fallback_mesh: ArrayMesh
var fallback_material: CanvasItemMaterial
var use_fallback := false
var fill := Color()
var edge := Color()
var style_key: Array = []

func configure(owner_officer) -> void:
	officer = owner_officer
	z_index = 1999
	shader_material = ShaderMaterial.new()
	shader_material.shader = WarningShader
	material = shader_material
	fallback_material = CanvasItemMaterial.new()
	fallback_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

func refresh(view: Rect2, enabled: bool, daylight: bool) -> void:
	var reach: float = officer.view_radius()
	visible = enabled and not officer.world.is_under_roof(officer.position) and officer.search_zone().has_point(officer.position) and Rect2(officer.position-Vector2.ONE*reach,Vector2.ONE*reach*2).intersects(view)
	if not visible: return
	position = officer.position
	if radius != reach:
		radius = reach
		shader_material.set_shader_parameter("radius",radius)
		queue_redraw()
	shader_material.set_shader_parameter("observer",officer.position)
	shader_material.set_shader_parameter("facing",officer.facing)
	var zone: Rect2 = officer.search_zone()
	var key: Array = [officer.position,reach,officer.half_fov(),zone,officer.world.obstacle_revision,officer.world.crate]
	if blocker_key != key:
		blocker_key = key
		geometry_updates += 1
		blockers.clear()
		for rect in officer.world.sight_rects():
			if officer.position.distance_squared_to(officer.position.clamp(rect.position,rect.end)) <= (reach+1.5)*(reach+1.5):
				blockers.append(Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
		var fallback: bool = blockers.size() > MAX_BLOCKERS
		if fallback != use_fallback:
			use_fallback = fallback
			material = fallback_material if use_fallback else shader_material
			queue_redraw()
		if use_fallback:
			fallback_mesh = officer.view_mesh()
			queue_redraw()
		else:
			var packed := blockers.duplicate()
			packed.resize(MAX_BLOCKERS)
			shader_material.set_shader_parameter("blocker_count",blockers.size())
			shader_material.set_shader_parameter("blockers",packed)
		shader_material.set_shader_parameter("zone",Vector4(zone.position.x,zone.position.y,zone.size.x,zone.size.y))
		shader_material.set_shader_parameter("half_angle",officer.half_fov())
	var color := Color("eb977b") if officer.state == "chasing" or officer.alert_mode() else Color("e1c787")
	var style: Array = [color,daylight]
	if style_key != style:
		style_key = style
		edge = color
		edge.a = 0.48
		fill = color
		fill.a = 0.12 if daylight else 0.0
		shader_material.set_shader_parameter("edge_color",edge)
		shader_material.set_shader_parameter("fill_alpha",fill.a)
		if use_fallback: queue_redraw()

func _draw() -> void:
	if not use_fallback:
		# One retained quad; GPU clips the exact circle against nearby walls.
		draw_rect(Rect2(-Vector2.ONE*(radius+2),Vector2.ONE*(radius+2)*2),Color.WHITE)
		return
	if fill.a > 0 and fallback_mesh != null and fallback_mesh.get_surface_count() > 0: draw_mesh(fallback_mesh,null,Transform2D.IDENTITY,fill)
	var line: PackedVector2Array = officer.view_polygon()
	if officer.half_fov() >= PI-0.00001 and not line.is_empty(): line.append(line[0])
	if line.size() >= 2: draw_polyline(line,edge,1.2,true)
