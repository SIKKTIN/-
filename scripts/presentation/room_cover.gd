extends Node2D

const Geometry = preload("res://scripts/presentation/roof_geometry.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const MANIFEST := "res://art/architecture/room_roofs_v47/manifest.json"
static var assets: Dictionary = {}
var visibility_rules
var room: Dictionary
var area := Rect2()
var roof := Rect2()
var panels: Array[Rect2] = []
var cutouts: Array[Rect2] = []
var ports: Array = []
var roof_texture: Texture2D
var cap_texture: Texture2D
var style := "concrete"
var shared_edges: Array[String] = []
var draw_builds := 0

static func definitions() -> Dictionary:
	if assets.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		for entry in data.assets: assets[str(entry.id)] = entry
	return assets

static func style_for(spec: Dictionary) -> String:
	if str(spec.get("roof_style","auto")) in ["concrete","dark_concrete","metal_green","metal_light"]: return str(spec.roof_style)
	if str(spec.kind)=="dorm": return "concrete"
	if str(spec.kind)=="confinement": return "dark_concrete"
	if str(spec.id)=="workshop" or str(spec.id)=="warehouse": return "metal_green"
	if str(spec.id).begins_with("cafeteria"): return "metal_light"
	return "concrete"

func configure(rules, spec: Dictionary) -> void:
	visibility_rules = rules
	room = spec
	area = room.area
	var layout: Dictionary = room.roof_plan
	roof = layout.roof
	panels.assign(layout.panels)
	cutouts.assign(layout.cutouts)
	ports = layout.ports
	style = style_for(room)
	var id := "roof_concrete_dark" if style=="dark_concrete" else "roof_concrete_warm" if style=="concrete" else "roof_"+style
	roof_texture = WorldTexture.load_asset(definitions()[id])
	cap_texture = rules.game.world.art_textures.get("cafeteria_coping_v23")
	# Doors/facades on the lower boundary keep their actual depth. Side/north
	# openings are removed from the mesh at their existing display footprint.
	z_index = mini(4094,int(area.end.y)-1)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for other in rules.rooms:
		if str(other.id)==str(room.id): continue
		var peer: Rect2 = other.roof_plan.roof
		if minf(peer.end.x,roof.end.x)-maxf(peer.position.x,roof.position.x)>20:
			if absf(peer.end.y-roof.position.y)<2: shared_edges.append("north")
			if absf(peer.position.y-roof.end.y)<2: shared_edges.append("south")
		if minf(peer.end.y,roof.end.y)-maxf(peer.position.y,roof.position.y)>20:
			if absf(peer.end.x-roof.position.x)<2: shared_edges.append("west")
			if absf(peer.position.x-roof.end.x)<2: shared_edges.append("east")
	_make_details()
	tick(0,true)

func tick(delta: float, immediate := false) -> void:
	var target := 0.0 if visibility_rules.active_id==str(room.id) else 1.0
	if modulate.a==target and not immediate: return
	modulate.a = target if immediate else move_toward(modulate.a,target,maxf(delta,0)/0.2)
	visible = modulate.a>0.001

func _make_details() -> void:
	var details: Array = []
	match str(room.id):
		"workshop": details = [["roof_vent_hood",Vector2(0.28,0.40)],["roof_vent_hood",Vector2(0.72,0.40)]]
		"warehouse": details = [["roof_vent_hood",Vector2(0.5,0.24)],["roof_vent_hood",Vector2(0.5,0.72)]]
		"equipment": details = [["roof_fan",Vector2(0.65,0.42)],["roof_drain_vent",Vector2(0.22,0.30)]]
		"laundry": details = [["roof_fan",Vector2(0.72,0.32)]]
		_:
			if str(room.id).begins_with("cafeteria"):
				details = [["roof_kitchen_flue",Vector2(0.84,0.24)],["roof_fan",Vector2(0.2,0.27)]]
			else: details = [["roof_drain_vent",Vector2(0.78,0.28)]]
	for detail in details:
		var asset: Dictionary = definitions()[detail[0]]
		var size := Vector2(asset.world_size[0],asset.world_size[1])
		var target := Rect2(roof.position+roof.size*detail[1]-size*0.5,size)
		if not roof.grow(-18).encloses(target) or cutouts.any(func(c): return c.intersects(target)): continue
		var sprite := Sprite2D.new()
		sprite.texture = WorldTexture.load_asset(asset)
		sprite.position = target.get_center()
		sprite.scale = target.size/sprite.texture.get_size()
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/presentation/roof_attachment.gdshader")
		sprite.material = mat
		add_child(sprite)

func _repeat(texture: Texture2D, rect: Rect2, tile: Vector2, tint := Color.WHITE) -> void:
	var points := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var uvs := PackedVector2Array()
	for point in points: uvs.append((point-roof.position)/tile)
	draw_polygon(points,PackedColorArray([tint,tint,tint,tint]),uvs,texture)

func _edge(side: String) -> Rect2:
	var width := 6.0 if side in shared_edges else 14.0
	match side:
		"north": return Rect2(roof.position,Vector2(roof.size.x,width))
		"south": return Rect2(roof.position.x,roof.end.y-width,roof.size.x,width)
		"west": return Rect2(roof.position,Vector2(width,roof.size.y))
	return Rect2(roof.end.x-width,roof.position.y,width,roof.size.y)

func _draw() -> void:
	draw_builds += 1
	# One repeated-UV quad per retained panel; no tiles or geometry rebuilt by
	# AI ticks/camera movement. Different roof materials share a world scale.
	for panel in panels:
		draw_rect(panel,Color("5d635d"))
		_repeat(roof_texture,panel,Vector2(320,320))
	if style.begins_with("metal"):
		var ridge := Rect2(roof.position.x+14,roof.position.y+roof.size.y*0.5-3,roof.size.x-28,6)
		for part in Geometry.subtract_all(ridge,cutouts):
			draw_rect(part,Color("7d837a"))
			draw_line(part.position,Vector2(part.end.x,part.position.y),Color("b0b2a0"),1,true)
			draw_line(Vector2(part.position.x,part.end.y),part.end,Color("3e4947"),1,true)
	# The retained shell owns the original stone caps/corners/door returns.
	# Only the membrane and its attachments fade, never a second roof frame.
	if room.get("retained_wall_edges",false): return
	for side in ["north","south","west","east"]:
		for part in Geometry.subtract_all(_edge(side),cutouts):
			draw_rect(part,Color("b9b7a1"))
			if cap_texture: _repeat(cap_texture,part,Vector2(64,64))
			draw_rect(part,Color("424c48"),false,1.3,true)
			draw_line(part.position+Vector2(1,1),Vector2(part.end.x-1,part.position.y+1),Color("ddd9bd"),1,true)
	# Recessed returns join a north/side entrance to the roof perimeter, so a
	# retained gate reads as a doorway instead of a sprite pasted on the roof.
	for opening in cutouts:
		var returns: Array[Rect2] = [Rect2(opening.position.x-5,opening.position.y,5,opening.size.y),Rect2(opening.end.x,opening.position.y,5,opening.size.y)]
		if opening.end.y < roof.end.y: returns.append(Rect2(opening.position.x-5,opening.end.y,opening.size.x+10,5))
		for strip in returns:
			var clipped := strip.intersection(roof)
			if not clipped.has_area(): continue
			for part in Geometry.subtract_all(clipped,cutouts):
				draw_rect(part,Color("acae99"))
				draw_rect(part,Color("424c48"),false,1,true)
	# A shallow fascia sits on the existing front wall, never a detached house
	# facade. The underside remains above the physical threshold/door.
	if "south" not in shared_edges:
		var fascia := Rect2(roof.position.x,roof.end.y,roof.size.x,5)
		for part in Geometry.subtract_all(fascia,cutouts): draw_rect(part,Color("3f4843"))
