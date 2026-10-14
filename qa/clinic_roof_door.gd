extends SceneTree
const OUT := "res://docs/art/clinic-restoration/"
var checks := {}
var game
func check(label: String, passed: bool): checks[label]=passed
func _initialize():call_deferred("run")
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://clinic-roof-door-qa.cfg")
	root.size=Vector2i(1280,900)
	root.content_scale_size=root.size
	var disk:=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.world.admission_filter=Callable()
	var actor=game.actors[0]
	var door=game.room_visibility.doorways.by_id("fixture:campus-clinic")
	var rect: Rect2=door.visual_rect
	var solid_profile: Dictionary=door.gate
	var sliding: bool=solid_profile.has("sliding_door")
	check("door collision follows painted leaves",solid_profile.has("sliding_door") or solid_profile.get("visual_solid_parts",[]).size()>2)
	for x in [68,132]:
		var start:=Vector2(rect.position.x+x,rect.end.y+40)
		check("ghost location free "+str(x),game.world.can_place_circle(start,game.ACTOR_RADIUS,actor,false))
		actor.position=start+Vector2(0,40)
		var movement: Vector2=game.world.move_actor(actor,Vector2(0,-40))
		check("can approach former ghost location "+str(x),movement.distance_to(Vector2(0,-40))<.01)
	for x in [60,140]:
		check(("full body clears stowed leaf " if sliding else "head stops at swung leaf ")+str(x),game.world.can_place_circle(Vector2(rect.position.x+x,rect.end.y+30),game.ACTOR_RADIUS,actor,false)==sliding)
	actor.position=Vector2(rect.get_center().x,rect.end.y+110)
	for y in range(int(rect.position.y)+90,int(rect.end.y)+110,4):
		check("clear central door lane "+str(y),game.world.door_body_clear(Vector2(rect.get_center().x,y)))
	game.room_visibility.tick(0,true)
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="clinic")[0]
	check("medical roof visible outdoors",cover.visible and cover.modulate.a==1)
	check("new membrane loaded once across roof",cover.style=="clinic" and cover.roof_texture!=null and cover.roof_tile==cover.roof.size)
	for id in ["clinic_roof_skylight","clinic_roof_extractor","clinic_roof_drain"]:check(id+" present",cover.has_node(id))
	check("old generic vent removed",not cover.has_node("roof_drain_vent"))
	var records: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"roof-registration.json"))
	for entry in records.assets:check("original roof PNG "+entry.key,FileAccess.get_sha256("res://"+entry.path)==entry.sha256)
	var builds: int=cover.draw_builds
	for i in range(30):game.presentation.tick(0)
	await frame()
	check("static roof does not rebuild",cover.draw_builds==builds)
	game.get_node("HUD").hide()
	game.map_camera.center_on(cover.roof.get_center()+Vector2(0,40))
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	await frame()
	await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"roof-door-runtime.png")
	actor.position=game.room_visibility.rooms.filter(func(r):return r.id=="clinic")[0].area.get_center()
	game.room_visibility.tick(0,true)
	check("roof hides upon entering",not cover.visible and cover.modulate.a==0)
	check("new floor entrance stays passable",game.world.door_body_clear(Vector2(rect.get_center().x,rect.end.y+40)))
	check("saved layout untouched by QA",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"roof-door-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	game.queue_free()
	await frame()
	quit(0 if failed.is_empty() else 1)
