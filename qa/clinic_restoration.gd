extends SceneTree
const OUT := "res://docs/art/clinic-restoration/"
var game
var checks := {}
var clinic_shift := Vector2.ZERO
func clinic_point(x: float,y: float) -> Vector2: return Vector2(x,y)+clinic_shift
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void: checks[label] = passed
func clinic_wall(map: Dictionary, wall: Array) -> bool:
	var room: Array = map.visibility_rooms.filter(func(r): return r.id=="clinic")[0].rect
	return wall[0]>=room[0]-20 and wall[1]>=room[1]-120 and wall[0]+wall[2]<=room[0]+room[2]+20 and wall[1]+wall[3]<=room[1]+room[3]+40
func outside_walls(map: Dictionary) -> Array:
	var result: Array = []
	for i in map.walls.size():
		if clinic_wall(map,map.walls[i]): continue
		var surface: Dictionary = {}
		for s in map.architecture.wall_surfaces:
			if int(s.wall_index)==i: surface=s.duplicate(true); surface.erase("wall_index"); break
		result.append({"rect":map.walls[i],"surface":surface})
	return result
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://clinic-art-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://clinic-art-buttons.cfg")
	root.size = Vector2i(1280,900)
	root.content_scale_size = root.size
	var disk := FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map: Dictionary = JSON.parse_string(disk)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	for key in baseline:
		if key not in ["fixtures","floor_regions","resident_staff","clinic_restoration_version","clinic_compact_version","walls","architecture","zones","visibility_rooms","concept_plan"]: check("preserved map "+key,map.get(key)==baseline[key])
	check("all outside walls and collision surfaces unchanged",outside_walls(map)==outside_walls(baseline))
	for group in ["zones","visibility_rooms"]:
		check("preserved non-clinic "+group,map[group].filter(func(r):return r.id!="clinic")==baseline[group].filter(func(r):return r.id!="clinic"))
	var compact_rect: Array = map.visibility_rooms.filter(func(r):return r.id=="clinic")[0].rect
	clinic_shift = Vector2(compact_rect[0]-1520,compact_rect[1]-420)
	check("clinic compact dimensions",Vector2(compact_rect[2],compact_rect[3])==Vector2(520,500))
	for direction in ["horizontal","vertical"]:
		check("preserved other building plans "+direction,map.concept_plan[direction].filter(func(s):return not s.id.begins_with("clinic-"))==baseline.concept_plan[direction].filter(func(s):return not s.id.begins_with("clinic-")))
	check("preserved outside floors",map.floor_regions.filter(func(f):return f.id!="campus-clinic" and not f.id.begins_with("clinic-wear-"))==baseline.floor_regions.filter(func(f):return f.id!="campus-clinic" and not f.id.begins_with("clinic-wear-")))
	var original_clinic: Array = baseline.fixtures.filter(func(f): return str(f.get("id","")).begins_with("campus-clinic"))
	var remaining_old: Array = baseline.fixtures.filter(func(f): return f not in original_clinic)
	check("all other fixtures unchanged",map.fixtures.filter(func(f):return not str(f.get("id","")).begins_with("campus-clinic"))==remaining_old)
	var assets: Dictionary = preload("res://scripts/presentation/prop_catalog.gd").assets()
	if map.get("clinic_architecture_version",0)==1:
		var architecture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"architecture-registration.json"))
		for entry in architecture.assets:
			check("architecture "+entry.key+" original PNG preserved",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
		check("architectural style keeps physical wall layout",map.walls==baseline.walls)
		var unchanged_collision := true
		var medical_style := true
		for i in map.architecture.wall_surfaces.size():
			var surface: Dictionary = map.architecture.wall_surfaces[i]
			unchanged_collision = unchanged_collision and surface.collision_parts==baseline.architecture.wall_surfaces[i].collision_parts
			if clinic_wall(map,map.walls[int(surface.wall_index)]): medical_style = medical_style and str(surface.grid_tile_asset).begins_with("clinic_")
		check("architectural style keeps wall collision parts",unchanged_collision)
		check("clinic walls all use medical family",medical_style)
	var registrations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"registration.json"))
	for entry in registrations.assets:
		check(entry.key+" original PNG preserved",FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	for id in ["clinic_exam_bed_h","clinic_wash_counter_ns","clinic_medicine_drawers","clinic_preparation_counter_h","clinic_glass_cabinet","clinic_instrument_trolley","clinic_instrument_tray","clinic_medicine_supplies","clinic_linen_record","clinic_record_sign"]:
		check(id+" shared prop registered",assets.has(id))
		var texture: Texture2D = preload("res://scripts/presentation/world_texture.gd").load_asset(assets[id])
		check(id+" texture loads",texture!=null)
		check(id+" real transparent alpha",texture.get_image().get_pixel(0,0).a<0.03)
	var catalog = preload("res://scripts/editor/editor_catalog.gd").new()
	check("clinic props named in editor",catalog.entries.any(func(e):return e.id=="clinic_exam_bed_h" and e.name=="医务室横向诊疗床"))
	check("medic station can be added in editor",catalog.entries.any(func(e):return e.group=="resident_staff"))
	if map.get("clinic_architecture_version",0)==1:
		for id in ["clinic_corner_nw","clinic_corner_ne","clinic_corner_sw","clinic_corner_se","clinic_wall_h_00","clinic_wall_v_long","clinic_lintel_80","doorway_clinic_open_v1","clinic_frosted_window","clinic_wall_light","clinic_medical_sign"]:
			check(id+" in editor palette",catalog.entries.any(func(e):return e.id==id))
	var doc = preload("res://scripts/editor/map_document.gd").new()
	check("map opens in editor",doc.open_file("res://data/rooms/r04.json"))
	check("map validates",doc.validate().errors.is_empty())
	if map.get("clinic_architecture_version",0)==1:
		var door_ref: Dictionary = doc.add("fixtures",Vector2(3000,3000),"doorway_clinic_open_v1")
		var art: Dictionary = preload("res://scripts/presentation/doorway_geometry.gd").art_spec(doc.value(door_ref))
		check("editor-created medical doorway gets full art and body profile",art.has("door_art") and art.visual_jambs.size()==2 and not doc.value(door_ref).blocks_movement)
		doc.undo()
		check("medical doorway placement undo keeps saved fixture count",doc.data.fixtures.size()==map.fixtures.size())
	var reference := {"group":"resident_staff","index":0}
	check("medic station listed as point",reference in doc.entries() and not doc.is_rect(reference))
	var start: Vector2 = doc.geometry(reference).position
	var patrol: Array = doc.value(reference).patrol.duplicate(true)
	doc.begin()
	doc.set_geometry(reference,Rect2(start+Vector2(20,20),Vector2.ZERO))
	doc.commit()
	check("moving station moves indoor route",doc.value(reference).patrol[0]==[patrol[0][0]+20,patrol[0][1]+20])
	doc.undo()
	check("station movement undo",doc.geometry(reference).position==start and doc.value(reference).patrol==patrol)
	check("medic appearance selectable",doc.character_appearance(reference)=="clinic_medic")
	var malformed: Dictionary = doc.data.duplicate(true)
	malformed.resident_staff[0].patrol = [[120]]
	check("malformed resident routes rejected",not doc.check_shape(malformed).is_empty())
	var terrain=preload("res://scripts/presentation/region_terrain.gd")
	terrain.warm_map(map)
	for id in ["clinic_tiles_a","clinic_tiles_b"]: check(id+" room floor loaded",terrain.texture(id,"res://art/environment/clinic_restoration/manifest.json")!=null)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","backpack","strong"],139)
	game.world.admission_filter = Callable()
	game.actors[0].position = clinic_point(1790,680)
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
	check("one medic resident instantiated",game.resident_staff.actors.size()==1)
	var medic=game.resident_staff.actors.clinic_medic
	check("existing medic appearance reused",medic.definition.id=="clinic_medic" and medic.motion.walk.size()==8)
	check("character scale stays 1.4",preload("res://scripts/core/world_scale.gd").HUMAN==1.4 and is_equal_approx(preload("res://scripts/core/world_scale.gd").human_height(medic.definition),84))
	check("medic visible inside revealed clinic",medic.visible)
	check("medic full body uses shared foot-depth",medic.z_index==preload("res://scripts/presentation/world_depth.gd").for_y(medic.position.y,game.world.bounds.end.y))
	check("resident is separate from player and enemies",medic not in game.actors and medic!=game.guard and game.actors.size()==3)
	if map.get("clinic_architecture_version",0)==1:
		check("continuous corner coping texture loads",game.world.art_textures.has("clinic_corner_nw") and game.world.art_textures.has("clinic_corner_se"))
		var clinic_door = game.room_visibility.doorways.by_id("fixture:campus-clinic")
		var sliding: bool=clinic_door.gate.has("sliding_door")
		check("medical doorway art renders full leaves",(clinic_door.leaf_texture!=null if sliding else clinic_door.custom_texture!=null) and clinic_door.visual_rect.size.y>100)
		check("door threshold loads clinic-specific floor",clinic_door.floor_texture!=null and clinic_door.floor_asset=="clinic_tiles_a")
		check("whole-body passage clear between open leaves",game.world.can_place_circle(clinic_point(1790,955),game.ACTOR_RADIUS,game.actors[0],false))
		check("whole body clears left side of sliding aperture" if sliding else "whole body stops at drawn open left leaf",game.world.can_place_circle(clinic_point(1725,955),game.ACTOR_RADIUS,game.actors[0],false)==sliding)
		check("whole body clears right side of sliding aperture" if sliding else "whole body stops at drawn open right leaf",game.world.can_place_circle(clinic_point(1855,955),game.ACTOR_RADIUS,game.actors[0],false)==sliding)
		var opening: Rect2 = clinic_door.visual_rect
		for x in [68,132]:
			check("no invisible blocker below angled leaf "+str(x),game.world.can_place_circle(Vector2(opening.position.x+x,opening.end.y+40),game.ACTOR_RADIUS,game.actors[0],false))
		for x in [60,140]:
			check(("body clears stowed leaf " if sliding else "head still collides with visible leaf ")+str(x),game.world.can_place_circle(Vector2(opening.position.x+x,opening.end.y+30),game.ACTOR_RADIUS,game.actors[0],false)==sliding)
		var cover = game.room_visibility.covers.filter(func(c):return c.room.id=="clinic")[0]
		check("dedicated medical roof texture loaded",cover.style=="clinic" and cover.roof_texture!=null and cover.roof_tile==cover.roof.size)
		for id in ["clinic_roof_skylight","clinic_roof_extractor","clinic_roof_drain"]: check(id+" mounted on roof",cover.has_node(id))
	var origin := clinic_point(1790,990)
	for point in [clinic_point(1690,650),clinic_point(1660,700),clinic_point(1840,630),clinic_point(1910,625),clinic_point(1860,725)]:
		check("reachable clinic station "+str(point),not game.world.find_path(origin,point,game.actors[0],false,true).is_empty())
	var protected: Array = game.world.fixtures.filter(func(f):return str(f.get("id","")).begins_with("campus-clinic") and f.get("blocks_movement",false))
	for fixture in protected: check(fixture.id+" floor collision",not game.world.can_place_circle(fixture.rect.get_center(),game.ACTOR_RADIUS,null,false))
	for i in protected.size():
		for j in range(i+1,protected.size()): check("no footprint overlap "+protected[i].id+" / "+protected[j].id,not protected[i].rect.intersects(protected[j].rect))
	check("relocated south doorway stays traversable",game.world.can_place_circle(clinic_point(1790,950),game.ACTOR_RADIUS,game.actors[0],false))
	check("new east wall blocks passage",not game.world.can_place_circle(clinic_point(2050,650),game.ACTOR_RADIUS,null,false))
	check("old east wall removed",game.world.can_place_circle(clinic_point(2170,650),game.ACTOR_RADIUS,null,false))
	check("old south wall removed",game.world.can_place_circle(clinic_point(1600,1050),game.ACTOR_RADIUS,null,false))
	var home: Vector2 = medic.position
	var moved := false
	var crossed := false
	var frames_seen := {}
	for step in range(500):
		game.resident_staff.tick(0.1)
		moved = moved or medic.position.distance_to(home)>20
		crossed = crossed or not game.world.can_place_circle(medic.position,game.ACTOR_RADIUS,null,false)
		if medic.moving: frames_seen[medic.frame_index]=true
	check("medic patrol moves indoors",moved)
	check("medic patrol never crosses blockers",not crossed)
	check("medic walk uses all eight poses",frames_seen.size()==8)
	var stopped: Vector2 = medic.position
	game.phase = "failed"
	game.resident_staff.tick(1)
	check("finished game stops resident movement",medic.position==stopped)
	game.phase = "playing"
	game.resident_staff.reset()
	medic = game.resident_staff.actors.clinic_medic
	check("reset restores resident station without duplicates",medic.position==home and game.resident_staff.actors.size()==1)
	game.map_camera.center_on(clinic_point(1780,650))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	game.mobile_controls.pad.hide()
	await shot("clinic-runtime")
	game.get_node("HUD").visible = false
	await shot("clinic-runtime-clear")
	game.get_node("HUD").visible = true
	for id in ["campus-clinic-cabinet-0","campus-clinic-cabinet-1"]:
		var state: Dictionary = game.looting.containers[id]
		game.actors[0].position = state.fixture.rect.get_center()+Vector2(0,state.fixture.rect.size.y/2+32)
		game.room_visibility.tick(0,true)
		check(id+" accessible for medical search",game.looting.reason(id).is_empty())
		check(id+" open",game.looting.open(id))
		game.looting.tick(30)
		check(id+" medical loot",state.ids.all(func(item):return game.inventory.instances[item].definition_id in game.looting.tables.profiles.medical.items))
		if not state.ids.is_empty():
			var item: String = state.ids[0]
			check(id+" take",game.looting.take(item).ok)
			var destination:=preload("res://scripts/items/grid_packing.gd").first_space(state.layout,Vector2i(4,4),game.inventory.item_size(game.inventory.instances[item].definition_id))
			check(id+" drag back",game.looting.move_item(item,"bag","source",destination).ok)
		game.looting.close()
	game.actors[0].position = clinic_point(1850,1180)
	game.room_visibility.tick(0,true)
	game.resident_staff.tick(0)
	check("medic hidden by clinic roof outside",not medic.visible)
	var medical_cover = game.room_visibility.covers.filter(func(c):return c.room.id=="clinic")[0]
	check("dedicated roof visible outside",medical_cover.visible and medical_cover.modulate.a==1)
	game.get_node("HUD").hide()
	game.map_camera.center_on(clinic_point(1780,650))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("clinic-exterior")
	game.hide()
	game.get_node("HUD").visible = false
	game.map_camera.enabled = false
	root.canvas_transform = Transform2D.IDENTITY
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.canvas.choose(reference)
	await frame()
	editor.canvas.zoom = 0.60
	editor.canvas.origin = editor.canvas.size/2-clinic_point(1780,630)*editor.canvas.zoom
	editor.canvas.queue_redraw()
	check("resident inspector offers appearance selector",editor.inspector.find_child("CharacterAppearance",true,false)!=null)
	check("editor resident in actor layer",editor.layers.key_for("resident_staff")=="actors")
	await shot("clinic-editor")
	editor.queue_free()
	await frame()
	check("QA does not change saved map",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free()
	await frame()
	await frame()
	quit(0 if failed.is_empty() else 1)
