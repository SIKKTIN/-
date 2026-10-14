extends SceneTree
const OUT := "res://docs/art/drying-yard-v1/"
const Assets = preload("res://scripts/presentation/prop_catalog.gd")
const SpriteTextures = preload("res://scripts/presentation/world_texture.gd")
const Proportions = preload("res://scripts/presentation/prop_proportions.gd")
var checks := {}
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(label: String, passed: bool) -> void:
	checks[label]=passed
	if not passed:print("FAILED: ",label)
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func finish() -> void:
	var failed: Array=checks.keys().filter(func(label):return not checks[label])
	var mode := "candidate" if "--candidate" in OS.get_cmdline_user_args() else "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"drying_yard_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://drying-yard-v1-qa.cfg")
	root.size=Vector2i(1440,1000)
	root.content_scale_size=root.size
	var document=load("res://scripts/editor/map_document.gd").new()
	if "--candidate" in OS.get_cmdline_user_args():
		check("candidate opens",document.open_file(OUT+"candidate-map.json"))
		var validation: Dictionary=document.validate()
		check("candidate validates",validation.errors.is_empty())
		if not validation.errors.is_empty():print(validation.errors)
		finish()
		return
	var path := "res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := raw(OUT+"before-map.json")
	var after := raw(OUT+"after-map.json")
	var current := raw(path)
	var registration := raw(OUT+"map-registration.json")
	var production := raw(OUT+"production-assets.json")
	check("existing furnishings preserved",before.fixtures==after.fixtures.filter(func(f):return f.id not in registration.new_fixture_ids))
	check("existing lights preserved",before.lamps==after.lamps.filter(func(f):return f.get("id","") not in registration.new_lamp_ids))
	check("other floors preserved",before.floor_regions.filter(func(f):return f.id not in registration.changed_floor_ids)==after.floor_regions.filter(func(f):return f.id not in registration.changed_floor_ids))
	var same := true
	for key in before:
		if key not in ["fixtures","floor_regions","lamps","concept_plan"] and before[key]!=after[key]:same=false
	check("walls gates roofs rooms routines and gameplay preserved",same)
	check("latest saved map retains yard",current.fixtures.filter(func(f):return f.id in registration.new_fixture_ids)==after.fixtures.filter(func(f):return f.id in registration.new_fixture_ids))
	for a in production.pngs:
		check("original PNG retained "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
		var im := Image.load_from_file("res://"+a.path)
		check("transparent PNG with clean shader edges "+a.key,im.get_format()==Image.FORMAT_RGBA8 and im.detect_alpha()!=Image.ALPHA_NONE and im.get_pixel(0,0).a<.02)
	var definitions := Assets.assets()
	for id in production.definition_ids:
		var a: Dictionary=definitions[id]
		var source: Vector2=Proportions.source_size(a)
		check("sprite aspect preserved "+id,is_equal_approx(float(a.world_size[0])/source.x,float(a.world_size[1])/source.y))
		var texture: Texture2D=SpriteTextures.load_asset(a)
		check("bounded runtime sprite loads "+id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
	check("clothesline atlas regions separated",definitions.drying_clothesline_sheets_v1.region[1]+definitions.drying_clothesline_sheets_v1.region[3]<definitions.drying_clothesline_clothes_v1.region[1])
	var game=load("res://scenes/main.tscn").instantiate()
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
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	var player=game.actors[0]
	player.position=Vector2(1460,2930)
	var yard: Array=game.world.fixtures.filter(func(f):return f.get("drying_yard_generated",false))
	check("twenty three editable exterior props installed",yard.size()==23)
	check("three clotheslines two west one east",yard.filter(func(f):return str(f.asset_id).contains("clothesline")).size()==3)
	check("two benches and four low flowerbeds",yard.filter(func(f):return f.asset_id=="drying_bench_v1").size()==2 and yard.filter(func(f):return str(f.asset_id).contains("flowerbed")).size()==4)
	for x in [1335.0,1460.0,1585.0]:
		check("central path clear both ways "+str(x),game.world.motion_clear(Vector2(x,2580),Vector2(x,3280),player,false,true) and game.world.motion_clear(Vector2(x,3280),Vector2(x,2580),player,false,true))
	check("western surrounding path stays open",game.world.motion_clear(Vector2(845,2580),Vector2(845,3210),player,false,true))
	check("eastern surrounding path stays open",game.world.motion_clear(Vector2(2170,2580),Vector2(2170,3210),player,false,true))
	check("south cross path stays open",game.world.motion_clear(Vector2(980,3250),Vector2(2250,3250),player,false,true))
	check("left rows reachable from center",not game.world.find_path(Vector2(1460,2900),Vector2(1100,2900),player,false,true).is_empty())
	check("linen cart reachable from center",not game.world.find_path(Vector2(1460,2990),Vector2(1750,3060),player,false,true).is_empty())
	for f in yard:
		if str(f.asset_id).contains("clothesline"):
			var solids: Array=game.world.fixture_collision_rects(f)
			check("clothesline only blocks post feet "+f.id,solids.size()==2 and not game.world.can_place_circle(solids[0].get_center(),8,player,false,false) and game.world.can_place_circle(f.rect.get_center(),8,player,false,false))
		elif f.asset_id in ["drying_linen_cart_v1","drying_flowerbed_long_v1","drying_flowerbed_square_v1","drying_bench_v1"]:
			check("solid base blocks feet "+f.id,not game.world.can_place_circle(f.rect.get_center(),8,player,false,false))
	check("foliage remains soft ground detail",yard.filter(func(f):return str(f.asset_id).contains("shrubs")).all(func(f):return not f.blocks_movement and not f.blocks_sight))
	game.world.set_access_closed("cafeteria-south",false)
	check("cafeteria doorway still passes both ways",game.world.motion_clear(Vector2(1540,2430),Vector2(1540,2600),player,false,true) and game.world.motion_clear(Vector2(1540,2600),Vector2(1540,2430),player,false,true))
	game.world.set_access_closed("cafeteria-rear",false)
	var north: Dictionary=game.world.access_by_id("cafeteria-rear")
	var laundry_out: Vector2=north.rect.get_center()-Vector2(0,180)
	var laundry_in: Vector2=north.rect.get_center()+Vector2(0,110)
	game.schedule.clock_elapsed=(750.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.room_access.tick()
	check("laundry doorway still passes both ways",game.world.motion_clear(laundry_out,laundry_in,player,false,true) and game.world.motion_clear(laundry_in,laundry_out,player,false,true))
	game.room_visibility.tick(0,true)
	game.map_camera.zoom=Vector2(.9,.9)
	game.map_camera.position=Vector2(1500,2860)-Vector2(root.size)/1.8
	game.map_camera.force_update_scroll()
	await frame()
	game.presentation.tick(0)
	check("yard is outdoors with no roof",yard.all(func(f):return not game.world.is_under_roof(f.rect.get_center())))
	check("all exterior props visible in live rendering",yard.all(func(f):return game.presentation.volumes.any(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==f.id and v.visible)))
	await shot("runtime-day")
	var overlap := false
	for i in range(yard.size()):
		for j in range(i+1,yard.size()):
			if yard[i].blocks_movement and yard[j].blocks_movement:
				for a in game.world.fixture_collision_rects(yard[i]):
					for b in game.world.fixture_collision_rects(yard[j]):
						if a.intersects(b):overlap=true
	check("solid furniture does not overlap",not overlap)
	var new_lights: Array=game.room_config.lamps.filter(func(l):return l.get("id","") in registration.new_lamp_ids)
	check("new lamps use existing lighting system without duplicate fixtures",new_lights.size()==2 and new_lights.all(func(l):return not l.draw_fixture))
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	if editor.canvas==null:
		check("editor initializes",false)
		finish()
		return
	check("editor ground layer is fully registered",editor.layers.NAMES.has("ground") and editor.layers.GROUPS.has("ground") and editor.layers.key_for("fixtures")=="fixtures" and editor.layers.key_for("floor_regions")=="ground" and editor.layers.locked.ground)
	editor.open_now(path)
	await frame()
	await frame()
	check("saved map validates in editor",editor.document.validate().errors.is_empty())
	for id in production.definition_ids:
		check("editor palette exposes "+id,editor.catalog.entries.any(func(e):return e.id==id and e.subcategory=="furnishings"))
	editor.canvas.zoom=.6
	editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2750)*editor.canvas.zoom
	editor.resource_search.text="晾晒区"
	editor.rebuild_palette()
	editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("editor preview starts with clean saved map",not editor.document.dirty())
	check("QA never saves simulation into project map",FileAccess.get_sha256(path)==disk)
	editor.queue_free()
	await frame()
	finish()
