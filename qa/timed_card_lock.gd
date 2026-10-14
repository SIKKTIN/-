extends SceneTree
const Geometry=preload("res://scripts/presentation/doorway_geometry.gd")
var game
var checks: Dictionary={}
func _initialize():call_deferred("run")
func check(label: String,value: bool):
	checks[label]=value
	if not value:push_error(label)
func clock(minute: float):
	game.schedule.clock_elapsed=(minute-float(game.schedule.config.start_minutes))*game.schedule.day_seconds/1440.0
	game.room_access.tick()
func near(gate: Dictionary,inside:=false):
	var rect:=Geometry.projected_rect(game.world,gate)
	game.actors[0].position=Vector2(rect.get_center().x,rect.position.y-30 if inside else rect.end.y+50)
func grant(kind: String)->String:
	var id: String=game.keycards.create({"kind":kind})
	game.inventory.bags[0].append(id)
	game.inventory.instances[id].location="bag"
	game.inventory.instances[id].actor_id=0
	return id
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://timed-card-lock.cfg")
	game=load("res://scripts/core/escape_game.gd").new();game.room_id="r04"
	root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.schedule.set_time_speed(0)
	for actor in game.actors:actor.position=Vector2(4000,4000)
	for id in game.inventory.items(0).duplicate():game.inventory.try_drop(0,str(id))
	var gate: Dictionary=game.keycards.gate("chess-entry")
	clock(19*60)
	check("room open within hours",not gate.closed)
	game.actors[0].position=game.keycards.room_area("chess-room").get_center()
	clock(20*60+1)
	check("closing locks despite occupant",gate.closed)
	check("no automatic evacuation opening",not game.room_access.closing.has("chess-entry"))
	near(gate,true)
	check("inside without card denied",not game.keycards.toggle(0,"chess-entry").ok)
	near(gate)
	for i in range(8):game.room_access.tick()
	check("approach cannot reopen closed door",gate.closed and not game.keycards.toggle(0,"chess-entry").ok)
	var wrong:=grant("logistics_card")
	check("unrelated card denied",not game.keycards.toggle(0,"chess-entry").ok)
	game.inventory.try_drop(0,wrong)
	var right:=grant("daily_card")
	check("matching card present",game.keycards.matching("chess-room")==right)
	check("matching card opens after closing",game.keycards.toggle(0,"chess-entry").ok and not gate.closed)
	for i in range(8):game.room_access.tick()
	check("swipe is not immediately undone by schedule",not gate.closed)
	var inside_point: Vector2=game.keycards.room_area("chess-room").get_center()
	check("after-hours admission accepts matching card",game.room_access.movement_allowed(game.actors[0],inside_point,8))
	game.actors[0].position=Vector2(4000,4000)
	game.world.set_access_closed("chess-entry",true,true);gate.manual_closed=true
	near(gate);game.inventory.try_drop(0,right)
	for i in range(8):game.room_access.tick()
	check("dropped card cannot reopen relocked room",gate.closed and not game.keycards.toggle(0,"chess-entry").ok)
	check("after-hours admission denies missing card",not game.room_access.movement_allowed(game.actors[0],inside_point,8))
	# Deferral prevents an OPEN door from closing on a body; it must never
	# turn an already CLOSED door into an open one.
	var closure: Rect2=game.world.door_collision_rect(gate.rect)
	game.actors[0].position=closure.get_center()-preload("res://scripts/core/actor_footprint.gd").DOOR_BODY.get_center()
	game.world.set_access_closed("chess-entry",true)
	check("body overlap does not reopen locked leaf",gate.closed)
	game.world.set_access_closed("chess-entry",false)
	game.world.set_access_closed("chess-entry",true)
	check("open leaf still waits for body to clear",not gate.closed)
	game.actors[0].position=Vector2(4000,4000)
	game.room_access.tick()
	check("leaf closes after body clears",gate.closed)
	clock(1440+9*60)
	check("next opening period restores scheduled access",not gate.closed)
	game.world.set_access_closed("chess-entry",true,true);gate.manual_closed=true
	game.room_access.tick()
	check("manual close is retained during open hours",gate.closed)
	game.reset_round([],2026)
	check("reset clears previous manual choice",not game.keycards.gate("chess-entry").has("manual_closed"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var path: String="res://docs/tests/timed-card-lock/"
	DirAccess.make_dir_recursive_absolute(path)
	FileAccess.open(path+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print("TIMED_CARD_LOCK ",checks.size()," failed=",failed)
	game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
