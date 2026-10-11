extends SceneTree
const OUT := "res://docs/art/factory-occupations-v48/"
const Library=preload("res://scripts/presentation/character_library.gd")
var checks: Dictionary={}
var game
func _initialize() -> void:call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label]=value
	if not value:print("FAIL: ",label)
func run() -> void:
	check("fourteen registered identities",Library.all().size()==14)
	for id in Library.all():
		var asset: Dictionary=Library.all()[id]
		check(id+" original PNG unchanged",FileAccess.get_sha256(asset.texture)==asset.sha256)
		check(id+" idle and portrait native resources",Library.idle(id)!=null and Library.portrait(id)!=null)
		check(id+" eight walk frames",asset.walk_animation.frames.size()==8)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],52);game.schedule.set_time_speed(0)
	paused=false
	var actor=game.actors[1]
	var visual=game.presentation.visuals.filter(func(v):return v.actor==actor)[0]
	actor.position=game.actors[0].position+Vector2(50,0)
	game.room_visibility.tick(0,true)
	check("default player retained",not game.presentation.visuals[0].definition.has("appearance_id"))
	check("NPC worker appearances differ",game.presentation.visuals[1].definition.appearance_id!=game.presentation.visuals[2].definition.appearance_id)
	var guard_visual=game.presentation.visuals.filter(func(v):return v.actor==game.guard)[0]
	check("patrol gets approved lookout",guard_visual.definition.appearance_id=="patrol_guard" and guard_visual.is_guard)
	if game.workshop.overseer!=null:
		var overseer=game.presentation.visuals.filter(func(v):return v.actor==game.workshop.overseer)[0]
		check("overseer has distinct approved identity",overseer.definition.appearance_id=="overseer" and overseer.is_guard)
	for id in Library.all():
		game.room_config.character_appearances={"actor:1":id}
		visual.refresh_appearance();actor.moved_this_frame=true
		var visited: Dictionary={};var feet_good:=true
		for i in range(16):
			visual.tick_visual(1.0/12.0)
			visited[visual.walk_frame_index]=true
			feet_good=feet_good and absf(visual.body_bounds().end.y)<1
		check(id+" all eight animation poses play",visited.size()==8 and not visited.has(-1))
		check(id+" foot registration stable",feet_good)
		actor.moved_this_frame=false;actor.facing=Vector2.LEFT;visual.tick_visual(0)
		check(id+" idle and mirrored body resolve",visual.frame_name=="idle" and visual.flip_h and visual.texture!=null)
	check("body nodes not duplicated",actor.get_child_count()==1)
	var merchant_id: String=game.trade.actors.keys()[0]
	game.room_config.character_appearances={"merchant:"+merchant_id:"cleaner"}
	game.items_view.tick_visuals()
	check("merchant supports selected identity without losing foot layer",game.items_view.merchant_appearances.has("cleaner") and game.items_view.merchant_visuals[merchant_id].actor==game.trade.actors[merchant_id])
	game.room_config.character_appearances={"actor:0":"truck_driver"}
	game.presentation.reset()
	check("player selected appearance survives presentation reset",game.presentation.visuals[0].definition.appearance_id=="truck_driver")
	game.load_room("r03",["lockpick","chat","backpack"],53)
	check("map switch clears previous override",not game.presentation.visuals[0].definition.has("appearance_id"))
	var doc=load("res://scripts/editor/map_document.gd").new();doc.open_file("res://data/rooms/r04.json")
	var ref={"group":"starts","index":1}
	doc.set_character_appearance(ref,"clinic_medic")
	check("editor assigns available appearance",doc.character_appearance(ref)=="clinic_medic")
	doc.undo();check("appearance change supports undo",doc.character_appearance(ref)=="")
	doc.redo();check("appearance change supports redo",doc.character_appearance(ref)=="clinic_medic")
	var preview: String=doc.preview_file()
	var reopened=load("res://scripts/editor/map_document.gd").new();reopened.open_file(preview)
	check("appearance survives save and reopen",reopened.character_appearance(ref)=="clinic_medic")
	DirAccess.remove_absolute(preview)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":checks.size()-failed.size(),"failed":failed,"checks":checks},"  "))
	print(JSON.stringify({"passed":checks.size()-failed.size(),"failed":failed}))
	game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
