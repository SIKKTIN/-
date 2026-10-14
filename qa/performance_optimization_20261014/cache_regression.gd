extends SceneTree
const OUT="res://docs/dev/performance-optimization-2026-10-14/"
const Geometry=preload("res://scripts/presentation/doorway_geometry.gd")
const Store=preload("res://scripts/presentation/runtime_texture_store.gd")
var checks: Dictionary={}
func _initialize():call_deferred("run")
func check(label: String,value: bool):
	checks[label]=value
	if not value:print("FAIL "+label)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://performance-cache-qa.cfg")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;game.set_process(false);game.fullscreen_ui.set_process(false)
	game.schedule.set_time_speed(0)
	var gates: Array=game.world.dorm_gates()
	for gate in gates:game.world.dorm_closure_rect(gate)
	var builds: int=game.world.dorm_geometry_builds
	for i in range(100):
		for gate in gates:game.world.dorm_closure_rect(gate)
	check("500 repeated geometry requests do not rebuild",game.world.dorm_geometry_builds==builds)
	var gate: Dictionary=gates[0];var old: Rect2=gate.rect
	var original: Rect2=game.world.dorm_closure_rect(gate)
	gate.rect.position+=Vector2(40,-20)
	check("moving gate invalidates cached bounds",game.world.dorm_closure_rect(gate)==Geometry.closed_art_bounds(game.world,gate) and game.world.dorm_closure_rect(gate)!=original)
	gate.rect=old
	var parts: Array=gate.closed_visual_solid_parts.duplicate(true)
	gate.closed_visual_solid_parts[0][0]+=13
	check("nested geometry edits invalidate cache",game.world.dorm_closure_rect(gate)==Geometry.closed_art_bounds(game.world,gate))
	gate.closed_visual_solid_parts=parts
	gate.rotation_quarters=posmod(int(gate.rotation_quarters)+1,4)
	check("rotation invalidates cached bounds",game.world.dorm_closure_rect(gate)==Geometry.closed_art_bounds(game.world,gate))
	gate.rotation_quarters=posmod(int(gate.rotation_quarters)+3,4)
	game.world.walls.append(Rect2(0,0,20,20));game.world._changed(true)
	builds=game.world.dorm_geometry_builds
	game.world.dorm_closure_rect(gate)
	check("wall edit invalidates geometry via collision revision",game.world.dorm_geometry_builds>builds)
	game.world.walls.pop_back();game.world._changed(true)
	var sync: int=game.world.dorm_sync_count
	game._process(1.0/60)
	check("one centralized door update in an ordinary frame",game.world.dorm_sync_count-sync==1)
	var catalog=preload("res://scripts/presentation/prop_catalog.gd")
	var first: Dictionary=catalog.assets();var id: String=first.keys()[0];var expected: Dictionary=first[id].duplicate(true)
	first[id].name="qa mutation"
	check("catalog callers cannot mutate cached definitions",catalog.assets()[id]==expected)
	var samples: Array=[]
	for room in ["r01","r04","r03","r04","r01","r04"]:
		check("load "+room+str(samples.size()),game.load_room(room,["chat","chat","backpack"],136))
		await process_frame;await process_frame
		check("reload retains a populated texture set "+str(samples.size()),not game.world.art_textures.is_empty())
		check("legacy exit icon survives scene release "+str(samples.size()),game.world.art_textures.has("exit_v01"))
		samples.append({"room":room,"cache":preload("res://scripts/presentation/world_texture.gd").cache.size(),"texture_mib":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	check("repeated R04 cache ownership is bounded",int(samples[1].cache)==int(samples[3].cache) and int(samples[3].cache)==int(samples[5].cache))
	check("baked textures used for scene dependencies",Store.hits>300)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"cache-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"reloads":samples,"baked_hits":Store.hits,"baked_misses":Store.misses},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
