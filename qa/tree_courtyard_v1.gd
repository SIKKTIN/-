extends SceneTree
const OUT := "res://docs/art/tree-courtyard-restoration-v1/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
const Terrain = preload("res://scripts/presentation/region_terrain.gd")
var checks := {}
var game
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func raw(path: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAILED: ",label)
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func finish():
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var mode := "candidate" if "--candidate" in OS.get_cmdline_user_args() else "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"tree_court_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://tree-court-qa.cfg")
	root.size=Vector2i(1440,1000)
	root.content_scale_size=root.size
	var doc=load("res://scripts/editor/map_document.gd").new()
	if "--candidate" in OS.get_cmdline_user_args():
		check("candidate opens",doc.open_file(OUT+"candidate-map.json"))
		var result: Dictionary=doc.validate()
		check("candidate validates",result.errors.is_empty())
		if not result.errors.is_empty():print(result.errors)
		finish()
		return
	var path := "res://data/rooms/r04.json"
	var hash := FileAccess.get_sha256(path)
	var before := raw(OUT+"before-map.json")
	var after := raw(OUT+"after-map.json")
	var record := raw(OUT+"registration.json")
	var production := raw(OUT+"production-assets.json")
	# Preserve the four additive cafeteria display edits that arrived between
	# the first garden save and polish, recorded from that latest source snapshot.
	var external := raw(OUT+"concurrent-map-updates.json")
	for group in external.groups:
		for update in external.groups[group]:
			var index: int=before[group].find(update.before)
			check("external update source verified "+update.id,index>=0)
			if index>=0:before[group][index]=update.after
	check("physical walls and wall profiles unchanged",before.walls==after.walls and before.architecture==after.architecture)
	check("doors and access rules unchanged",before.access_doors==after.access_doors and before.dorm_doors==after.dorm_doors)
	check("all roof and room visibility bounds unchanged",before.visibility_rooms==after.visibility_rooms)
	check("outside furnishings unchanged",before.fixtures.filter(func(f):return f.id not in record.changed_fixture_ids and f.id not in record.get("removed_fixture_ids",[]))==after.fixtures.filter(func(f):return f.id not in record.changed_fixture_ids and not f.get("tree_court_generated",false)))
	check("outside floor regions unchanged",before.floor_regions.filter(func(f):return f.id not in record.removed_floor_ids)==after.floor_regions.filter(func(f):return not f.get("tree_court_generated",false)))
	check("original ground details retained",before.ground_details==after.ground_details.filter(func(f):return not f.get("tree_court_generated",false)))
	for key in ["starts","patrol","free","items","workshop","cafeteria","confinement","resident_staff"]:
		check("gameplay records preserved "+key,before.get(key)==after.get(key))
	check("seven new original PNGs supplied",production.pngs.size()==7)
	for asset in production.pngs:
		check("source pixels unchanged "+asset.key,FileAccess.get_sha256("res://"+asset.path)==asset.sha256)
		if not asset.key.ends_with("tile"):
			var im := Image.load_from_file("res://"+asset.path)
			check("transparent background "+asset.key,im.detect_alpha()!=Image.ALPHA_NONE and im.get_pixel(0,0).a==0)
	var defs := Catalog.assets()
	for id in production.definition_ids:check("native prop loads "+id,Textures.load_asset(defs[id])!=null)
	for id in production.ground_ids:check("new ground texture loads "+id,Terrain.texture(id,"res://art/environment/tree_courtyard_v1/manifest.json")!=null)
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
		actor.position=Vector2(200,200)
	game.guard.position=Vector2(3590,1960)
	game.guard.set_process(false)
	game.dog.position=Vector2(3500,1400)
	var world=game.world
	var player=game.actors[0]
	player.position=Vector2(3000,2425)
	var entries := [Vector2(3590,1890),Vector2(2950,2425),Vector2(4210,2425),Vector2(3590,2900)]
	for i in range(entries.size()):
		check("approach foot position free "+str(i),world.can_place_circle(entries[i],8,player,false,false))
		check("garden remains outdoors "+str(i),game.room_visibility.room_at(entries[i]).is_empty())
		for j in range(i+1,entries.size()):
			var route: PackedVector2Array=world.find_path(entries[i],entries[j],player,false,true)
			var cursor: Vector2=entries[i]
			var clear: bool=not route.is_empty()
			for point in route:
				clear=clear and world.motion_clear(cursor,point,player,false,true)
				cursor=point
			check("approaches connected by valid collision path %d-%d" % [i,j],clear)
	for x in [3290,3920]:
		check("complete north-south ring aisle clear "+str(x),world.motion_clear(Vector2(x,2170),Vector2(x,2650),player,false,true))
	# Existing warehouse door leaves are access geometry owned by that room;
	# the garden must reach its exterior threshold without changing their state.
	check("east walk reaches warehouse exterior threshold",world.motion_clear(Vector2(4100,2425),Vector2(4240,2355),player,false,true))
	var marked: Array=world.fixtures.filter(func(f):return f.get("concept_marked_cluster",false))
	check("all five user-marked clusters placed",marked.size()==5)
	check("five clusters use five different originals",marked.map(func(f):return f.asset_id).reduce(func(a,v):if v not in a:a.append(v);return a,[]).size()==5)
	# fixture_collision_rects returns potential shape even for nonblocking art;
	# validate the actual movement rule and the planted ground position instead.
	for f in marked:check("foliage does not obstruct paths "+f.id,not f.blocks_movement and world.can_place_circle(f.rect.get_center(),8,player,false,false))
	for id in ["courtyard-north-west","courtyard-north-east","courtyard-west-south","courtyard-east-south"]:
		var f: Dictionary=world.fixtures.filter(func(a):return a.id==id)[0]
		check("stone planter collision retained "+id,not world.fixture_collision_rects(f).is_empty())
	game.room_visibility.tick(0,true)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.65,.65)
	game.map_camera.position=Vector2(3570,2410)-Vector2(root.size)/1.3
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await shot("runtime-day")
	game.presentation.lighting.set_period("night")
	await shot("runtime-night")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	check("saved map validates",editor.document.validate().errors.is_empty())
	for id in production.definition_ids:check("editor palette includes "+id,editor.catalog.entries.any(func(e):return e.id==id))
	editor.canvas.zoom=.52
	editor.canvas.origin=editor.canvas.size/2-Vector2(3570,2390)*editor.canvas.zoom
	editor.resource_search.text="自强树庭"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("editor opens cleanly",not editor.document.dirty())
	check("QA leaves project map unchanged",hash==FileAccess.get_sha256(path))
	finish()
