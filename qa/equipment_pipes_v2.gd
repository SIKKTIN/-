extends SceneTree

const OUT := "res://docs/art/equipment-pipes-v2/"
const Catalog = preload("res://scripts/presentation/prop_catalog.gd")
const Textures = preload("res://scripts/presentation/world_texture.gd")
var checks := {}
var game
func _initialize() -> void:call_deferred("run")
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func check(label: String,value: bool) -> void:
	checks[label]=value
	if not value:print("FAILED: ",label)
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://equipment-pipes-qa.cfg")
	root.size=Vector2i(1440,1100)
	root.content_scale_size=root.size
	var path: String="res://data/rooms/r04.json"
	var disk := FileAccess.get_sha256(path)
	var before := read(OUT+"before-map.json")
	var after := read(path)
	var receipt := read(OUT+"registration.json")
	# The subsequently approved valve restoration owns only its explicitly
	# recorded exterior fixtures, one floor patch and its maintenance gate.
	var valve := read("res://docs/art/valve-maintenance-v1/registration.json") if after.has("valve_maintenance_version") else {}
	var perimeter := read("res://docs/art/valve-perimeter-v2/registration.json") if after.ground_details.any(func(s):return s.get("valve_perimeter_generated",false)) else {}
	# Other approved room edits can postdate the original pipe installation.
	# The valve task captured the latest saved map before touching anything;
	# use that evidence for unrelated areas, while retaining the pipe-specific
	# original source, removed-fragment, geometry and endpoint checks below.
	var reference := read("res://docs/art/valve-maintenance-v1/before-map.json") if not valve.is_empty() else before
	var doc=load("res://scripts/editor/map_document.gd").new()
	check("map loads",doc.open_file(path))
	check("map validates",doc.validate().errors.is_empty())
	for key in reference:
		if key=="access_doors" and not valve.is_empty():
			check("unrelated map data retained "+key,reference[key]==after[key].filter(func(g):return g.id!=valve.added_access_id))
		elif key=="floor_regions" and not valve.is_empty():
			check("unrelated map data retained "+key,reference[key].filter(func(f):return f.id not in valve.changed_floor_ids)==after[key].filter(func(f):return f.id not in valve.changed_floor_ids))
		elif key=="ground_details" and not perimeter.is_empty():
			check("unrelated map data retained "+key,reference[key].filter(func(s):return s not in perimeter.removed_ground_details)==after[key].filter(func(s):return not s.get("valve_perimeter_generated",false)))
		elif key!="fixtures":check("unrelated map data retained "+key,reference[key]==after[key])
	var modified: Array=receipt.removed_fixture_ids.duplicate()
	modified.append_array(valve.get("removed_fixture_ids",[]))
	check("other props and exterior pipes unchanged",reference.fixtures.filter(func(f):return f.id not in modified and not f.get("equipment_pipe_generated",false))==after.fixtures.filter(func(f):return not f.get("equipment_pipe_generated",false) and not f.get("valve_maintenance_generated",false)))
	check("fragmented original internal pipes removed",not after.fixtures.any(func(f):return f.id in receipt.removed_fixture_ids))
	var definitions := Catalog.assets()
	var pipes: Array=after.fixtures.filter(func(f):return f.get("equipment_pipe_generated",false))
	check("eight editable connected runs installed",pipes.size()==8)
	check("source PNG byte identical",FileAccess.get_sha256("res://art/props/pipe_energy_court_v1/pipe-fittings.png")==receipt.source_sha256)
	for f in pipes:
		var a: Dictionary=definitions.get(f.asset_id,{})
		check("asset loads "+f.id,not a.is_empty() and Textures.load_asset(a)!=null)
		check("no invisible pipe wall "+f.id,not f.blocks_movement and not a.blocking)
		check("continuous pipe bodies "+f.id,a.assembly_patches.any(func(p):return p.role=="continuous_body"))
		check("no open socket textures repeated "+f.id,a.assembly_patches.all(func(p):return p.role in ["continuous_body","flanged_support","curved_elbow"]))
	game=load("res://scenes/main.tscn").instantiate()
	game.room_id="r04"
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.get_node("HUD").hide()
	for actor in game.actors:
		actor.set_process(false);actor.set_physics_process(false);actor.immune_until=INF
	game.guard.position=Vector2(3500,1600)
	game.dog.position=Vector2(3500,1700)
	game.map_camera.following=false
	game.map_camera.zoom=Vector2(.76,.76)
	game.map_camera.position=Vector2(2900,3340)-Vector2(root.size)/1.52
	game.map_camera.force_update_scroll()
	game.actors[0].position=Vector2(2990,3800)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	# Each route end must join another same-color run or terminate inside a
	# real rendered device / wall penetration. A floating end is a defect.
	var ports: Array[Rect2]=[]
	for v in game.presentation.volumes:
		if v.kind=="fixture" and game.world.fixtures[v.wall_index].id in ["energy-court-tank","equipment-secure-pump","equipment-secure-control_bank"]:
			ports.append(v.display_rect)
	ports.append(Rect2(2780,2890,30,55))
	for f in pipes:
		for color in f.pipe_routes:
			var points: Array=f.pipe_routes[color]
			for end in [points.front(),points.back()]:
				var endpoint := Vector2(end[0],end[1])
				var joined: bool=false
				# Bounds include transparent sprite padding; verify an opaque
				# source pixel so a visually floating socket cannot pass.
				for v in game.presentation.volumes:
					if v.kind!="fixture" or game.world.fixtures[v.wall_index].id not in ["energy-court-tank","equipment-secure-pump","equipment-secure-control_bank"]:continue
					if not v.display_rect.has_point(endpoint):continue
					var df: Dictionary=definitions[game.world.fixtures[v.wall_index].asset_id]
					var region: Array=df.region
					var uv: Vector2=(endpoint-v.display_rect.position)/v.display_rect.size
					var pixel := Vector2i(Vector2(region[0],region[1])+uv*Vector2(region[2],region[3]))
					var source := Image.load_from_file(df.texture)
					if source.get_pixelv(pixel).a>.80:joined=true
				if Rect2(2780,2890,30,55).has_point(endpoint):joined=true
				for other in pipes:
					if other.id==f.id or not other.pipe_routes.has(color):continue
					var line: Array=other.pipe_routes[color]
					for i in range(line.size()-1):
						var a := Vector2(line[i][0],line[i][1])
						var b := Vector2(line[i+1][0],line[i+1][1])
						if Geometry2D.get_closest_point_to_segment(endpoint,a,b).distance_to(endpoint)<.1:joined=true
				check("end joins circuit or device "+f.id+" "+color+" "+str(endpoint),joined)
	for v in game.presentation.volumes:
		if v.kind=="fixture" and game.world.fixtures[v.wall_index].get("equipment_pipe_generated",false):
			check("visible in room "+game.world.fixtures[v.wall_index].id,v.visible)
	check("service aisle remains walkable",not game.world.find_path(Vector2(2990,3800),Vector2(2690,3050),game.actors[0],false,true).is_empty())
	check("pump approach remains clear",game.world.motion_clear(Vector2(2800,3800),Vector2(2740,3590),game.actors[0],false,true))
	await shot("runtime-interior")
	game.actors[0].position=Vector2(2990,4045)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	for v in game.presentation.volumes:
		if v.kind=="fixture" and game.world.fixtures[v.wall_index].get("equipment_pipe_generated",false):
			check("hidden under roof "+game.world.fixtures[v.wall_index].id,not v.visible)
	await shot("runtime-exterior")
	game.queue_free()
	await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	await frame()
	editor.open_now(path)
	await frame()
	for f in pipes:
		check("run in editor palette "+f.id,editor.catalog.entries.any(func(e):return e.id==f.asset_id))
		var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(v):return v.id==f.id)[0])
		check("run can be selected "+f.id,not editor.canvas.architecture_preview.visual_hit_areas({"group":"fixtures","index":index}).is_empty())
	editor.canvas.zoom=.53
	editor.canvas.origin=editor.canvas.size/2-Vector2(2930,3320)*editor.canvas.zoom
	editor.resource_search.text="设备室管线"
	editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-pipes")
	check("QA leaves map unchanged",FileAccess.get_sha256(path)==disk)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var mode := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(OUT+"checks-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"equipment_pipe_checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
