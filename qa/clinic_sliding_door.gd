extends SceneTree
const OUT := "res://docs/art/clinic-restoration/"
const Sliding = preload("res://scripts/presentation/sliding_door_geometry.gd")
var game
var checks := {}
func check(label: String,passed: bool):checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func minute(value: float):
	game.schedule.clock_elapsed=(value-float(game.schedule.config.start_minutes))/1440*game.schedule.day_seconds
	game.schedule.tick(false)
func clear_doors():
	var door=game.room_visibility.doorways.by_id("clinic-entry")
	var point:=Vector2(door.visual_rect.get_center().x,door.visual_rect.end.y+110)
	game.actors[0].position=point
	for actor in game.actors.slice(1):actor.position=actor.home
	game.guard.position=Vector2(3000,1500)
	game.dog.position=Vector2(3100,1500)
	if game.resident_staff:game.resident_staff.actors.clinic_medic.position=Vector2(1600,300)
func shot(name: String):
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")

func crossing_visible(door):
	var actor=game.actors[0]
	actor.position=Vector2(door.visual_rect.get_center().x,door.visual_rect.end.y-20)
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	await frame()
	await frame()
	var visual=game.presentation.visuals[0]
	check("threshold floor stays below whole actor",door.get_node("ThresholdFloor").z_index<actor.z_index and not door.get_node("ThresholdFloor").z_as_relative)
	check("passage floor separated from raised leaves",door.leaf_texture!=null and door.get_node("ThresholdFloor")!=door)
	if DisplayServer.get_name()=="headless":return
	var with_actor: Image=root.get_texture().get_image()
	with_actor.save_png(OUT+"sliding-crossing-runtime.png")
	var transform: Transform2D=visual.get_global_transform_with_canvas()
	var bounds: Rect2=transform*visual.body_bounds()
	visual.hide()
	await frame()
	var without_actor: Image=root.get_texture().get_image()
	var pixels:=0
	for y in range(maxi(0,floori(bounds.position.y)),mini(with_actor.get_height(),ceili(bounds.end.y))):
		for x in range(maxi(0,floori(bounds.position.x)),mini(with_actor.get_width(),ceili(bounds.end.x))):
			var difference: Color=with_actor.get_pixel(x,y)-without_actor.get_pixel(x,y)
			if absf(difference.r)+absf(difference.g)+absf(difference.b)>.1:pixels+=1
	check("rendered whole character visible in empty aperture",pixels>500)
	visual.show()
	await frame()
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://clinic-sliding-qa.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var map: Dictionary=JSON.parse_string(disk)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"sliding-last-input-map.json"))
	# Compare the registration snapshots: live editor changes made afterwards
	# belong to the user and must not be treated as importer mutations.
	var imported: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"sliding-last-output-map.json"))
	for key in before:
		if key not in ["fixtures","access_doors"]:check("saved layout preserved "+key,imported[key]==before[key])
	check("unrelated fixtures preserved",imported.fixtures.filter(func(f):return f.id!="campus-clinic")==before.fixtures.filter(func(f):return f.id!="campus-clinic"))
	check("unrelated access rules preserved",imported.access_doors.filter(func(g):return g.id!="clinic-entry")==before.access_doors.filter(func(g):return g.id!="clinic-entry"))
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"sliding-door-registration.json"))
	check("registration input snapshot verified",FileAccess.get_sha256(OUT+"sliding-last-input-map.json")==records.map_before_sha256)
	check("registration output snapshot verified",FileAccess.get_sha256(OUT+"sliding-last-output-map.json")==records.map_after_sha256)
	for entry in records.assets:check("original PNG preserved "+entry.key,FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	clear_doors()
	minute(480)
	game.room_visibility.tick(0,true)
	var door=game.room_visibility.doorways.by_id("clinic-entry")
	var gate: Dictionary=game.world.access_by_id("clinic-entry")
	var rect: Rect2=door.visual_rect
	check("fixture and gate share one visual",game.room_visibility.doorways.by_id("fixture:campus-clinic")==door)
	check("physics and paint share gate state",game.world.door_passage.by_id("clinic-entry")==gate and door.gate==gate)
	check("door artwork loaded",door.leaf_texture!=null and door.has_node("SlidingTrack"))
	check("opens at 08:00",not gate.closed and gate.slide_fraction==0)
	check("clear full-body central opening by day",game.world.can_place_circle(Vector2(rect.get_center().x,rect.end.y+40),game.ACTOR_RADIUS,game.actors[0],false))
	var leaves:=Sliding.leaves(gate,0)
	check("both leaves stowed completely outside aperture",leaves[0].end.x<=0 and leaves[1].position.x>=rect.size.x)
	check("leaf does not shrink when opening",leaves[0].size==Sliding.leaves(gate,1)[0].size)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="clinic")[0]
	game.map_camera.center_on(cover.roof.get_center()+Vector2(0,100))
	game.map_camera.force_update_scroll()
	game.get_node("HUD").hide()
	await shot("sliding-day-runtime")
	await crossing_visible(door)
	clear_doors()
	game.room_visibility.tick(0,true)
	game.presentation.tick(0)
	minute(1199)
	check("open at 19:59",not gate.closed)
	minute(1200)
	check("close requested at 20:00",gate.closed)
	game.room_visibility.tick(.20)
	check("visible horizontal closing transition",gate.slide_fraction>0 and gate.slide_fraction<1)
	var phase: float=gate.slide_fraction
	var state: Array=Sliding.world_solids(gate,rect,phase)
	var proposed: Array=Sliding.world_solids(gate,rect,minf(1,phase+.2))
	check("moving collision follows leaf coordinates",state[0].position.x<proposed[0].position.x and state[1].position.x>proposed[1].position.x)
	for i in range(8):game.room_visibility.tick(.10)
	check("closed animation completes",gate.slide_fraction==1)
	var closed:=Sliding.leaves(gate,1)
	check("closed leaves meet at centre",closed[0].end.x==closed[1].position.x and closed[0].position.x==0 and closed[1].end.x==rect.size.x)
	check("whole body blocked at night",not game.world.can_place_circle(Vector2(rect.get_center().x,rect.end.y+40),game.ACTOR_RADIUS,game.actors[0],false))
	check("closed door blocks sight",not game.world.line_clear(Vector2(rect.get_center().x,rect.position.y+30),Vector2(rect.get_center().x,rect.end.y+20)))
	await shot("sliding-night-runtime")
	var revisions: int=game.world.obstacle_revision
	var builds: int=door.draw_builds
	for i in range(30):game.room_visibility.tick(.01)
	await frame()
	check("idle night does not rebuild collisions",game.world.obstacle_revision==revisions)
	check("idle night retains art commands",door.draw_builds==builds)
	minute(1440+479)
	check("stays closed at 07:59 next day",gate.closed)
	minute(1440+480)
	game.room_visibility.tick(.20)
	check("next morning visibly slides open",not gate.closed and gate.slide_fraction>0 and gate.slide_fraction<1)
	for i in range(8):game.room_visibility.tick(.1)
	check("next morning fully reopened",gate.slide_fraction==0)
	# Explicit body in the passage delays closure, without moving the player.
	game.actors[0].position=Vector2(rect.get_center().x,rect.end.y+20)
	var position: Vector2=game.actors[0].position
	minute(1440+1200)
	game.room_visibility.tick(.3)
	check("person at threshold delays night closure",not gate.closed and gate.slide_fraction==0 and game.actors[0].position==position)
	clear_doors()
	game.room_access.tick()
	game.room_visibility.tick(.65)
	check("closes after threshold clears",gate.closed and gate.slide_fraction==1)
	# Someone enters the swept area after a close request: back off the leaf.
	gate.closed=false
	game.room_visibility.tick(0,true)
	gate.closed=true
	game.room_visibility.tick(.1)
	var previous: float=gate.slide_fraction
	game.actors[0].position=Vector2(rect.position.x+rect.size.x*.5,rect.end.y+20)
	game.room_visibility.tick(.6)
	check("moving leaf backs off before clamping",gate.slide_fraction<=previous)
	clear_doors()
	game.room_access.tick()
	game.room_visibility.tick(.65)
	game.get_tree().paused=true
	var paused_fraction: float=gate.slide_fraction
	game.room_visibility.tick(1)
	check("pause freezes door motion",gate.slide_fraction==paused_fraction)
	game.get_tree().paused=false
	game.reset_round()
	door=game.room_visibility.doorways.by_id("clinic-entry")
	check("reset restores morning door state",not door.gate.closed and door.gate.slide_fraction==0)
	var document=preload("res://scripts/editor/map_document.gd").new()
	check("editor saved map validates",document.open_file("res://data/rooms/r04.json") and document.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	check("sliding door available in editor",catalog.entries.any(func(e):return e.id=="doorway_clinic_sliding_v2"))
	check("QA does not change saved map",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"sliding-door-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
