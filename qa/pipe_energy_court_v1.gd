extends SceneTree
const OUT := "res://docs/art/pipe-energy-court-v1/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
const Compound = preload("res://scripts/core/room_visibility.gd")
const Transform = preload("res://scripts/editor/map_transform.gd")
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
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
func finish() -> void:
	var failed: Array=checks.keys().filter(func(k): return not checks[k])
	var mode := "candidate" if "--candidate" in OS.get_cmdline_user_args() else "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"energy_court_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func reveal(point: Vector2) -> void:
	game.actors[0].position=point
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://energy-court-v1-qa.cfg")
	root.size=Vector2i(1600,1050)
	root.content_scale_size=root.size
	var document=load("res://scripts/editor/map_document.gd").new()
	if "--candidate" in OS.get_cmdline_user_args():
		check("candidate opens",document.open_file(OUT+"candidate-map.json"))
		var validation: Dictionary=document.validate()
		check("candidate validates",validation.errors.is_empty())
		if not validation.errors.is_empty(): print(validation.errors)
		finish()
		return
	var map_path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(map_path)
	var before := raw(OUT+"before-map.json")
	var after := raw(OUT+"after-map.json")
	var registration := raw(OUT+"map-registration.json")
	var production := raw(OUT+"production-assets.json")
	check("all existing physical walls preserved",before.walls==after.walls.slice(0,before.walls.size()))
	check("all original wall surfaces preserved",before.architecture.wall_surfaces==after.architecture.wall_surfaces.filter(func(s): return not s.get("energy_court_generated",false)))
	check("unrelated furnishings preserved",before.fixtures.filter(func(f):return f.id not in registration.changed_fixture_ids)==after.fixtures.filter(func(f):return not f.get("energy_court_generated",false) and f.id not in registration.changed_fixture_ids))
	check("original gates and lock rules preserved",before.access_doors==after.access_doors.filter(func(g):return not g.get("energy_court_generated",false)))
	check("living buildings and roof ranges preserved",before.visibility_rooms.filter(func(r):return r.id not in registration.removed_visibility_ids)==after.visibility_rooms.filter(func(r):return not r.get("energy_court_generated",false)))
	check("original floors retained",before.floor_regions==after.floor_regions.filter(func(r):return not r.get("energy_court_generated",false)))
	var definitions := Catalog.assets()
	for asset in production.pngs:
		check("original source PNG unchanged "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
		if asset.key!="concrete-tile":
			var im := Image.load_from_file("res://"+asset.path)
			check("real transparent alpha "+asset.key,im.detect_alpha()!=Image.ALPHA_NONE and im.get_pixel(0,0).a<.01)
	for id in production.definition_ids:
		check("native asset loads "+id,Textures.load_asset(definitions[id])!=null)
	var room: Dictionary=after.visibility_rooms.filter(func(r):return r.id=="equipment")[0]
	var pieces := Compound.areas_for(room)
	check("equipment consists of two touching L wings",pieces.size()==2 and is_equal_approx(pieces[0].end.x,pieces[1].position.x) and pieces[0].end.y==pieces[1].end.y)
	check("outdoor notch excluded from equipment",not pieces.any(func(a):return a.has_point(Vector2(3200,3100))))
	var rotated: Dictionary=room.duplicate(true)
	for i in range(4): rotated=Transform.transform_item(rotated,Vector2(3000,3300),1,Vector2.ZERO)
	check("four editor rotations preserve compound shape",str(rotated.room_parts)==str(room.room_parts) and str(rotated.roof_cutouts)==str(room.roof_cutouts))
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:
		actor.immune_until=INF
		actor.set_process(false)
		actor.set_physics_process(false)
	game.guard.position=Vector2(3500,1600)
	game.dog.position=Vector2(3500,1700)
	var player=game.actors[0]
	var world=game.world
	var rules=game.room_visibility
	var owned: Array=world.fixtures.filter(func(f):return f.get("energy_court_generated",false))
	check("saved generated fixture collection installed",owned.size()==registration.new_fixture_ids.size())
	check("exactly five independent overhead bays",owned.filter(func(f):return f.asset_id=="energy_gantry_v1").size()==5)
	check("one long tank and one octagonal platform",owned.filter(func(f):return f.asset_id=="energy_tank_v1").size()==1 and owned.filter(func(f):return f.asset_id=="energy_platform_v1").size()==1)
	check("no stale repair or waste roofs",not rules.rooms.any(func(r):return r.id in ["repair","waste"]))
	check("notch is outdoors in actual game",rules.room_at(Vector2(3200,3100)).is_empty())
	check("both L wings belong to same room",rules.room_at(Vector2(2670,3100))=="equipment" and rules.room_at(Vector2(3100,3800))=="equipment")
	var roof=rules.covers.filter(func(c):return c.room.id=="equipment")[0]
	check("roof covers west and south wings",roof.panels.any(func(p):return p.has_point(Vector2(2450,3100))) and roof.panels.any(func(p):return p.has_point(Vector2(3200,3750))))
	check("roof excludes exterior L notch",not roof.panels.any(func(p):return p.has_point(Vector2(3200,3100))))
	for gate in [{"id":"energy-entry","outside":Vector2(2990,4030),"inside":Vector2(2990,3890)},{"id":"energy-court-entry","outside":Vector2(2990,3360),"inside":Vector2(2990,3610)}]:
		world.set_access_closed(gate.id,true)
		check("closed door blocks "+gate.id,not world.motion_clear(gate.outside,gate.inside,player,false,true))
		world.set_access_closed(gate.id,false)
		check("open door passes both ways "+gate.id,world.motion_clear(gate.outside,gate.inside,player,false,true) and world.motion_clear(gate.inside,gate.outside,player,false,true))
	check("southern service route clear both ways",world.motion_clear(Vector2(2160,4040),Vector2(5050,4040),player,false,true) and world.motion_clear(Vector2(5050,4040),Vector2(2160,4040),player,false,true))
	check("garden can reach southern service road",not world.find_path(Vector2(3440,2890),Vector2(3600,4030),player,false,true).is_empty())
	check("warehouse approach remains reachable",not world.find_path(Vector2(3600,3840),Vector2(4690,3360),player,false,true).is_empty())
	# The old probe (3100,3860) overlaps the projected south door jamb.
	# Use a free aisle point, and validate the entire returned route by collision.
	var aisle := Vector2(3100,3800)
	check("west and south aisle endpoints are free",world.can_place_circle(Vector2(2670,3020),8,player,false,false) and world.can_place_circle(aisle,8,player,false,false))
	var path: PackedVector2Array = world.find_path(Vector2(2670,3020),aisle,player,false,true)
	check("west and south equipment aisles connected",not path.is_empty())
	var cursor := Vector2(2670,3020)
	var clear: bool = not path.is_empty()
	for point in path:
		clear = clear and world.motion_clear(cursor,point,player,false,true)
		cursor = point
	check("complete cross-wing route clears furniture and walls",clear)
	for i in range(5):
		var f: Dictionary=owned.filter(func(v):return v.id=="energy-court-gantry-"+str(i))[0]
		var solids: Array=world.fixture_collision_rects(f)
		check("gantry only blocks narrow post "+str(i),solids.size()==1 and solids[0].size.x<30)
		var x: float=f.rect.position.x+65
		check("walk beneath overhead beam "+str(i),world.motion_clear(Vector2(x,2900),Vector2(x,3180),player,false,true))
	var platform: Dictionary=owned.filter(func(v):return v.id=="energy-court-valve-platform")[0]
	check("platform blocks its plinth center",not world.can_place_circle(platform.rect.get_center(),8,player,false,false))
	check("octagonal cut corner does not have square collision",world.can_place_circle(platform.rect.position+Vector2(8,8),4,player,false,false))
	# Compound-room support must retain existing rectangular visibility rules.
	for id in ["laundry","canteen","duty","office","workshop-two","warehouse"]:
		var legacy: Dictionary=rules.rooms.filter(func(r):return r.id==id)[0]
		var cover=rules.covers.filter(func(c):return c.room.id==id)[0]
		check("rectangular bounds preserved "+id,legacy.areas.size()==1 and legacy.areas[0]==legacy.area)
		reveal(legacy.area.get_center())
		check("rectangular interior reveal works "+id,rules.active_id==id and not cover.visible and rules.visible_at(legacy.area.get_center()))
		reveal(Vector2(3200,3100))
		check("rectangular exterior roof restores "+id,cover.visible and not rules.visible_at(legacy.area.get_center()))
	check("all compound notches stay visibly outdoors",rules.visible_at(Vector2(3200,3100)))
	reveal(aisle)
	check("entering south wing reveals entire L",rules.active_id=="equipment" and not roof.visible and rules.visible_at(Vector2(2500,3100)))
	reveal(Vector2(2670,3020))
	check("walking into west wing keeps shared roof lifted",rules.active_id=="equipment" and not roof.visible)
	reveal(Vector2(3200,3100))
	check("stepping into outdoor notch restores whole L roof",rules.active_id.is_empty() and roof.visible and world.is_under_roof(Vector2(2500,3100)) and not world.is_under_roof(Vector2(3200,3100)))
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.49,.49)
	game.map_camera.position=Vector2(3600,2980)-Vector2(root.size)/.98
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	check("player visible outside compound notch",game.presentation.visuals[0].visible)
	await shot("runtime-outside-roof")
	reveal(aisle)
	await shot("runtime-inside-equipment")
	game.presentation.lighting.set_period("night")
	await shot("runtime-night")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(map_path)
	await frame()
	await frame()
	check("map validates in editor",editor.document.validate().errors.is_empty())
	for id in production.definition_ids:
		check("editor palette includes "+id,editor.catalog.entries.any(func(e):return e.id==id))
	editor.canvas.zoom=.4
	editor.canvas.origin=editor.canvas.size/2-Vector2(3600,3030)*editor.canvas.zoom
	editor.resource_search.text="能源庭院"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("editor opens saved map cleanly",not editor.document.dirty())
	check("QA leaves saved map unchanged",FileAccess.get_sha256(map_path)==disk)
	finish()
