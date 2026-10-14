extends Node2D

const Geometry = preload("res://scripts/presentation/roof_geometry.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const MANIFEST := "res://art/architecture/room_roofs_v47/manifest.json"
const CLINIC_MANIFEST := "res://art/architecture/clinic_roof_v1/manifest.json"
const BATH_MANIFEST := "res://art/architecture/bath_v1/manifest.json"
const MONITOR_MANIFEST := "res://art/architecture/monitor_room_v1/roof-manifest.json"
const LAUNDRY_MANIFEST := "res://art/architecture/laundry_v1/roof-manifest.json"
const CAFETERIA_MANIFEST := "res://art/architecture/cafeteria_v2/manifest.json"
const TOOL_ROOM_MANIFEST := "res://art/architecture/tool_room_v1/manifest.json"
const KIOSK_MANIFEST := "res://art/architecture/kiosk_v1/manifest.json"
const READING_CHESS_MANIFEST := "res://art/architecture/reading_chess_roofs_v1/manifest.json"
const EQUIPMENT_MANIFEST := "res://art/architecture/equipment_secure_v1/manifest.json"
const ADMIN_ROOFS_MANIFEST := "res://art/architecture/administration_roofs_v1/manifest.json"
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
var roof_tile := Vector2(320,320)
var material_sections: Array[Dictionary] = []

static func definitions() -> Dictionary:
	if assets.is_empty():
		for path in [MANIFEST,CLINIC_MANIFEST,BATH_MANIFEST,MONITOR_MANIFEST,LAUNDRY_MANIFEST,CAFETERIA_MANIFEST,TOOL_ROOM_MANIFEST,KIOSK_MANIFEST,READING_CHESS_MANIFEST,EQUIPMENT_MANIFEST,ADMIN_ROOFS_MANIFEST]:
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			for entry in data.assets: assets[str(entry.id)] = entry
	return assets

static func style_for(spec: Dictionary) -> String:
	if str(spec.get("roof_style",""))=="kiosk": return "kiosk"
	if str(spec.get("roof_style","auto")) in ["concrete","dark_concrete","metal_green","metal_light","clinic","bath","monitor","laundry","cafeteria","workshop_two","tool_room","warehouse","reading","chess","office","duty"]: return str(spec.roof_style)
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
	var id := "toolroom_roof_surface" if style=="tool_room" else "cafeteria_roof_surface" if style=="cafeteria" else "laundry_roof_surface" if style in ["laundry","workshop_two","warehouse"] else "monitor_roof_surface" if style=="monitor" else "bath_roof_surface" if style=="bath" else "clinic_roof_surface" if style=="clinic" else "roof_concrete_dark" if style=="dark_concrete" else "roof_concrete_warm" if style=="concrete" else "roof_"+style
	if style=="kiosk": id = "kiosk_roof_v1"
	roof_texture = WorldTexture.load_asset(definitions()[id])
	roof_tile = roof.size if definitions()[id].get("fit_roof",false) else Vector2(320,320)
	# Compound rooms may author different materials for each roof wing.
	# Regions are normalized to the roof bounds and clipped to its L panels.
	for section: Dictionary in room.get("roof_sections",[]):
		var asset: Dictionary = definitions().get(str(section.get("asset_id","")),{})
		if asset.is_empty(): continue
		var values: Array = section.rect
		var region := Rect2(roof.position+Vector2(values[0],values[1])*roof.size,Vector2(values[2],values[3])*roof.size)
		var tile: Array = section.get("tile_size",[320,320])
		for panel in panels:
			var clipped := region.intersection(panel)
			if clipped.has_area(): material_sections.append({"rect":clipped,"texture":WorldTexture.load_asset(asset),"tile":Vector2(tile[0],tile[1])})
	cap_texture = rules.game.world.art_textures.get("cafeteria_coping_v23")
	# Doors/facades on the lower boundary keep their actual depth. Side/north
	# openings are removed from the mesh at their existing display footprint.
	z_index = preload("res://scripts/presentation/world_depth.gd").for_y(area.end.y+float(room.get("roof_depth_offset",0)),visibility_rules.game.world.bounds.end.y)-1
	for port in ports:
		var doorway = rules.doorways.by_id(str(port.id))
		if doorway != null and doorway.gate.get("roof_occludes_door",false):
			doorway.limit_roof_depth(z_index-1)
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
	# These fitted originals already include their roof-mounted details.
	if style in ["kiosk","reading","chess","office","duty"]: return
	var details: Array = []
	if room.has("roof_details"):
		for detail: Dictionary in room.roof_details:
			details.append([str(detail.asset_id),Vector2(detail.position[0],detail.position[1])])
	elif style=="warehouse":
		details = [["roof_vent_hood",Vector2(0.35,0.23)],["roof_vent_hood",Vector2(0.65,0.73)],["laundry_roof_skylight",Vector2(0.60,0.28)],["laundry_roof_skylight",Vector2(0.40,0.70)]]
	elif style=="tool_room":
		details = [["roof_vent_hood",Vector2(0.65,0.26)]]
	elif style=="workshop_two":
		details = [["roof_vent_hood",Vector2(0.28,0.30)],["roof_vent_hood",Vector2(0.76,0.30)],["laundry_roof_skylight",Vector2(0.52,0.62)]]
	elif style=="laundry":
		details = [["roof_vent_hood",Vector2(0.82,0.23)],["laundry_roof_skylight",Vector2(0.28,0.5)],["laundry_roof_skylight",Vector2(0.70,0.5)]]
	elif style=="cafeteria":
		details = [["roof_kitchen_flue",Vector2(0.68,0.20)],["roof_fan",Vector2(0.24,0.22)]]
	elif style=="monitor":
		details = [["roof_vent_hood",Vector2(0.78,0.23)],["roof_drain_vent",Vector2(0.20,0.14)]]
	elif style=="bath":
		details = [["bath_roof_vent",Vector2(0.25,0.20)],["bath_roof_vent",Vector2(0.75,0.20)],["clinic_roof_drain",Vector2(0.5,0.08)]]
	elif style=="clinic":
		details = [["clinic_roof_skylight",Vector2(0.29,0.16)],["clinic_roof_extractor",Vector2(0.80,0.27)],["clinic_roof_drain",Vector2(0.93,0.08)]]
	else:
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
		sprite.name = str(detail[0])
		if has_node(NodePath(sprite.name)):
			sprite.name = str(detail[0])+"_"+str(get_child_count())
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
	for panel in panels if material_sections.is_empty() else []:
		if style=="kiosk":
			# Side-entry cuts sample one continuous roof, not a fresh full image
			# per panel (which would duplicate vents and break metal seams).
			_repeat(roof_texture,panel,roof.size)
			continue
		draw_rect(panel,Color("5d635d"))
		_repeat(roof_texture,panel,roof_tile)
	for section in material_sections:
		draw_rect(section.rect,Color("5d635d"))
		_repeat(section.texture,section.rect,section.tile)
	if style.begins_with("metal") and material_sections.is_empty():
		var ridge := Rect2(roof.position.x+14,roof.position.y+roof.size.y*0.5-3,roof.size.x-28,6)
		for part in Geometry.subtract_all(ridge,cutouts):
			draw_rect(part,Color("7d837a"))
			draw_line(part.position,Vector2(part.end.x,part.position.y),Color("b0b2a0"),1,true)
			draw_line(Vector2(part.position.x,part.end.y),part.end,Color("3e4947"),1,true)
	if style=="laundry":
		# A thin gutter is retained in this roof's cached draw commands.
		var gutter := Rect2(roof.end.x-8,roof.position.y+5,5,roof.size.y-10)
		for part in Geometry.subtract_all(gutter,cutouts):
			draw_rect(part,Color("35444c"))
			draw_line(part.position,Vector2(part.position.x,part.end.y),Color("9ba8ad"),1,true)
	# The retained shell owns the original stone caps/corners/door returns.
	# Only the membrane and its attachments fade, never a second roof frame.
	if style=="kiosk": return
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
