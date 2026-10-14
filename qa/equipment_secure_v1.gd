extends SceneTree

const OUT := "res://docs/art/equipment-secure-v1/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
const Transform = preload("res://scripts/editor/map_transform.gd")
var checks := {}
var game

func _initialize() -> void: call_deferred("run")
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value: print("FAILED: ",label)
func raw(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png(OUT+name+".png")
func reveal(point: Vector2) -> void:
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
func finish() -> void:
	var failed: Array=checks.keys().filter(func(k): return not checks[k])
	var mode := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"equipment_secure_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)

func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://equipment-secure-qa.cfg")
	root.size=Vector2i(1600,1100)
	root.content_scale_size=root.size
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := raw(OUT+"before-map.json")
	var after := raw(OUT+"after-map.json")
	var registration := raw(OUT+"registration.json")
	var production := raw(OUT+"production-assets.json")
	var document=load("res://scripts/editor/map_document.gd").new()
	check("saved map opens",document.open_file(path))
	var validation: Dictionary=document.validate()
	check("saved map validates",validation.errors.is_empty())
	if not validation.errors.is_empty(): print(validation.errors)
	var owned: Array[int]=[]
	for value in registration.changed_wall_indices:owned.append(int(value))
	check("unchanged physical walls retain original positions",range(before.walls.size()).all(func(i):return i in owned or before.walls[i]==after.walls[i]))
	check("only equipment walls restyled",before.architecture.wall_surfaces.filter(func(s):return int(s.wall_index) not in owned)==after.architecture.wall_surfaces.filter(func(s):return int(s.wall_index) not in owned))
	check("other visibility rooms unchanged",before.visibility_rooms.filter(func(r):return r.id!="equipment")==after.visibility_rooms.filter(func(r):return r.id!="equipment"))
	check("other lock rules unchanged",before.access_doors.filter(func(g):return g.id not in ["energy-entry","energy-court-entry"])==after.access_doors.filter(func(g):return g.id!="energy-entry"))
	check("outside floor regions unchanged",before.floor_regions.filter(func(f):return f.id not in ["energy-court-equipment-west-floor","energy-court-equipment-south-floor"])==after.floor_regions.filter(func(f):return not f.get("equipment_secure_generated",false)))
	var modified: Array=registration.removed_fixture_ids.duplicate()
	modified.append("energy-court-energy-entry")
	# A concurrent task updated the distant main gate while this room was
	# refined. Compare against its captured records, never overwrite them.
	var unaffected: Array=before.fixtures.filter(func(f):return f.id not in modified)
	var concurrent: Dictionary=raw(OUT+"concurrent-map-updates.json")
	for fixture: Dictionary in concurrent.fixtures:
		var index := -1
		for i in range(unaffected.size()):
			if unaffected[i].id==fixture.id:index=i;break
		if index>=0:unaffected[index]=fixture
		else:unaffected.append(fixture)
	check("all outside props and pipeline fittings preserved",unaffected==after.fixtures.filter(func(f):return not f.get("equipment_secure_generated",false)))
	var definitions := Catalog.assets()
	for asset in production.pngs:
		check("generated PNG preserved "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
		if asset.key!="surfaces":
			var pixels := Image.load_from_file("res://"+asset.path)
			check("transparent source "+asset.key,pixels.detect_alpha()!=Image.ALPHA_NONE and pixels.get_pixel(0,0).a<.01)
	for id in production.definition_ids:
		check("asset loads "+id,definitions.has(id) and Textures.load_asset(definitions[id])!=null)
	var room: Dictionary=after.visibility_rooms.filter(func(r):return r.id=="equipment")[0]
	check("original L footprint retained",room.rect==before.visibility_rooms.filter(func(r):return r.id=="equipment")[0].rect and room.room_parts==before.visibility_rooms.filter(func(r):return r.id=="equipment")[0].room_parts)
	check("single controlled entrance",room.door_ids==["energy-entry"] and not after.access_doors.any(func(g):return g.id=="energy-court-entry"))
	var rotated:=room.duplicate(true)
	for i in range(4):rotated=Transform.transform_item(rotated,Vector2(2930,3300),1,Vector2.ZERO)
	check("roof wing materials follow four editor rotations",str(rotated.roof_sections)==str(room.roof_sections))
	check("roof attachments follow four editor rotations",str(rotated.roof_details)==str(room.roof_details))
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.immune_until=INF
	game.guard.position=Vector2(3500,1600)
	game.dog.position=Vector2(3500,1700)
	var world=game.world
	var rules=game.room_visibility
	var actor=game.actors[0]
	var door=world.access_by_id("energy-entry")
	check("locked front door initialized closed",door.closed and door.kind=="locked")
	check("front door art registered",door.asset_id=="doorway_equipment_secure_closed_v1")
	check("south door prevents unauthorized entry",not world.motion_clear(Vector2(2990,4030),Vector2(2990,3800),actor,false,true))
	check("sealed former court door blocks passage",not world.motion_clear(Vector2(2990,3370),Vector2(2990,3610),actor,false,true))
	check("public south road remains clear",world.motion_clear(Vector2(2180,4090),Vector2(3520,4090),actor,false,true))
	check("door foreground no invisible barrier",world.motion_clear(Vector2(2940,4045),Vector2(3030,4045),actor,false,true))
	world.set_access_closed("energy-entry",false)
	check("authorized open door passes in",world.motion_clear(Vector2(2990,4030),Vector2(2990,3800),actor,false,true))
	check("authorized open door passes out",world.motion_clear(Vector2(2990,3800),Vector2(2990,4030),actor,false,true))
	check("internal wing service path connected",not world.find_path(Vector2(2990,3800),Vector2(2690,3050),actor,false,true).is_empty())
	world.set_access_closed("energy-entry",true)
	check("tank cage prevents crossing from service aisle",not world.motion_clear(Vector2(2690,3050),Vector2(2550,3050),actor,false,true))
	check("tank front mesh prevents unauthorized entry",not world.motion_clear(Vector2(2520,3610),Vector2(2520,3450),actor,false,true))
	check("control cage blocks entry around left side",not world.motion_clear(Vector2(2970,3660),Vector2(3100,3660),actor,false,true))
	check("control cage blocks entry around right side",not world.motion_clear(Vector2(3520,3660),Vector2(3410,3660),actor,false,true))
	check("locked control mesh gate blocks front",not world.motion_clear(Vector2(3390,3820),Vector2(3390,3700),actor,false,true))
	for f in world.fixtures.filter(func(v):return str(v.id).begins_with("equipment-secure-") and str(v.asset_id).contains("mesh")):
		check("mesh has solid foot "+f.id,world.fixture_collision_rects(f).any(func(r):return r.has_area()))
	check("equipment watch is real NPC",game.gate_watch.by_id("equipment-secure-watch")!=null)
	check("equipment watch does not block primary gate",not game.gate_watch.by_id("equipment-secure-watch").blocks_primary)
	var roof=rules.covers.filter(func(c):return c.room.id=="equipment")[0]
	check("two material roof sections installed",roof.material_sections.size()>=2)
	check("roof excludes outdoor notch",not roof.panels.any(func(p):return p.has_point(Vector2(3200,3100))))
	var remaining: Array=[]
	var section_rects: Array=[]
	for section in roof.material_sections:section_rects.append(section.rect)
	for panel in roof.panels:remaining.append_array(preload("res://scripts/presentation/roof_geometry.gd").subtract_all(panel,section_rects))
	check("roof wings covered without material gaps",remaining.is_empty())
	check("custom sealed roof fittings installed",roof.get_child_count()==4)
	reveal(Vector2(2990,4045))
	check("whole roof visible from outside",roof.visible)
	for volume in game.presentation.volumes:
		if volume.kind!="fixture":continue
		var f: Dictionary=world.fixtures[volume.wall_index]
		if f.get("equipment_secure_generated",false) and not f.get("exterior_shell",false):
			check("interior hidden from outside "+f.id,not volume.visible)
		if f.get("equipment_secure_generated",false) and f.get("exterior_shell",false) and not f.has("access_id"):
			check("exterior security fixture visible "+f.id,volume.visible)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.66,.66)
	game.map_camera.position=Vector2(2940,3370)-Vector2(root.size)/1.32
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-exterior")
	reveal(Vector2(2990,3800))
	check("entry reveals same complete L room",rules.active_id=="equipment" and not roof.visible)
	for volume in game.presentation.volumes:
		if volume.kind=="fixture" and world.fixtures[volume.wall_index].id=="equipment-secure-control-desk":
			check("control desk visible above front facade",volume.visible and volume.display_rect.end.y<3840)
	await shot("runtime-interior")
	reveal(Vector2(2990,4045))
	check("leaving restores sealed roof",roof.visible)
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	await frame()
	for id in production.definition_ids:
		if definitions[id].get("editor_hidden",false) or definitions[id].get("render_mode","")=="architecture_material":continue
		check("asset available in editor "+id,editor.catalog.entries.any(func(e):return e.id==id))
	for id in registration.added_fixture_ids:
		var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(f):return f.id==id)[0])
		var ref: Dictionary={"group":"fixtures","index":index}
		check("editor can pick new fixture "+id,not editor.canvas.architecture_preview.visual_hit_areas(ref).is_empty())
	check("new industrial floor in palette",editor.catalog.entries.any(func(e):return e.get("asset_id","")=="equipment_secure_floor_v1"))
	editor.canvas.zoom=.48
	editor.canvas.origin=editor.canvas.size/2-Vector2(2930,3330)*editor.canvas.zoom
	editor.resource_search.text="机密设备室"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-restored")
	check("QA leaves saved map unchanged",FileAccess.get_sha256(path)==disk)
	finish()
