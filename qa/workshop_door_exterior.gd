extends SceneTree
const OUT = "res://docs/art/workshop-one-restoration/door-v2/"
var checks := {}
func check(label: String, passed: bool): checks[label] = passed
func _initialize(): call_deferred("run")
func rendered_frame():
	await process_frame
	await RenderingServer.frame_post_draw
func check_contact_pixels(game):
	if DisplayServer.get_name()=="headless": return
	game.get_node("HUD").hide()
	var player = game.actors[0]
	var visual = game.presentation.visuals[0]
	var gate: Dictionary = game.world.access_by_id("workshop-entry")
	for closed in [false,true]:
		player.position = Vector2(gate.rect.get_center().x,gate.rect.end.y+180)
		game.world.set_access_closed("workshop-entry",closed)
		for side in [-1,1]:
			player.position = Vector2(gate.rect.get_center().x+side*65,gate.rect.end.y+3.01)
			game.map_camera.center_on(player.position);game.map_camera.force_update_scroll()
			game.room_visibility.tick(0,true);game.presentation.tick(0)
			await rendered_frame(); await rendered_frame()
			var actual: Image = root.get_texture().get_image()
			var depth: int = player.z_index
			player.z_index = game.room_visibility.doorways.by_id("workshop-entry").z_index+10
			await rendered_frame()
			var reference: Image = root.get_texture().get_image()
			var area: Rect2 = visual.get_global_transform_with_canvas()*visual.body_bounds()
			var differences := 0
			for y in range(maxi(0,floori(area.position.y)),mini(actual.get_height(),ceili(area.end.y))):
				for x in range(maxi(0,floori(area.position.x)),mini(actual.get_width(),ceili(area.end.x))):
					var d := actual.get_pixel(x,y)-reference.get_pixel(x,y)
					if absf(d.r)+absf(d.g)+absf(d.b)>.03:differences+=1
			check("rendered whole actor visible at contact closed="+str(closed)+" side="+str(side),differences==0)
			actual.save_png(OUT+"contact-"+("closed" if closed else "open")+("-left" if side<0 else "-right")+".png")
			player.z_index=depth
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-exterior-qa.cfg")
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
	var before := FileAccess.get_sha256("res://data/rooms/r04.json")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); await process_frame
	game.set_process(false); game.fullscreen_ui.set_process(false)
	var player = game.actors[0]
	for id in ["workshop-entry","workshop-entry-east"]:
		var gate: Dictionary = game.world.access_by_id(id)
		var centre: float = gate.rect.get_center().x
		var base: float = gate.rect.end.y
		player.position = Vector2(centre,base+180)
		for closed in [false,true]:
			game.world.set_access_closed(id,closed)
			var prefix: String = id+" closed="+str(closed)
			for offset in [3.01,3.5,4.0,5.0,20.0,55.0]:
				player.position = Vector2(centre+65,base+offset)
				game.room_visibility.tick(0,true); game.presentation.tick(0)
				var view = game.room_visibility.doorways.by_id(id)
				check(prefix+" foreground actor in front at "+str(offset),player.z_index>view.z_index)
			player.position = Vector2(centre,base+180)
			for offset in [5,20,55,80,110]:
				var left := Vector2(gate.rect.position.x-35,base+offset)
				var right := Vector2(gate.rect.end.x+35,base+offset)
				check(prefix+" exterior sideways "+str(offset),game.world.motion_clear(left,right,player,false,true) and game.world.motion_clear(right,left,player,false,true))
				for side in [-1,1]:
					var point := Vector2(centre+side*65,base+offset)
					check(prefix+" exterior stand "+str(side)+" "+str(offset),game.world.can_place_circle(point,game.ACTOR_RADIUS,player,false,false))
			var from := Vector2(centre,base+55)
			var to := Vector2(centre,gate.rect.position.y-140)
			check(prefix+" centre passage matches state",game.world.motion_clear(from,to,player,false,true)==not closed)
			if not closed:
				var report := Vector2(centre+65,base+55)
				print("AIR_WALL_DIAGNOSTIC "+id+" "+str(report)+" body="+str(game.world.body_solids.filter(func(r):return r.has_point(report)))+" feet="+str(game.world.solid_rects(false).filter(func(r):return game.world._circle_hits_rect(report,game.ACTOR_RADIUS,r))))
				player.position = from
				var start: Vector2 = player.position
				game.world.move_actor(player,Vector2(120,0))
				check(prefix+" actual right movement clears reported point",player.position.distance_to(start+Vector2(120,0))<.1)
				game.world.move_actor(player,Vector2(-240,0))
				check(prefix+" actual left movement clears opposite jamb",player.position.distance_to(start-Vector2(120,0))<.1)
				check(prefix+" physical jamb remains blocked",not game.world.can_place_circle(Vector2(gate.rect.end.x,base-10),game.ACTOR_RADIUS,player,false,false))
				player.position = Vector2(centre,base+20)
				game.world.set_access_closed(id,true)
				check(prefix+" front actor does not prevent closure",gate.closed)
				game.world.set_access_closed(id,false)
				player.position = Vector2(centre,base-10)
				game.world.set_access_closed(id,true)
				check(prefix+" crossing actor still prevents closure",not gate.closed)
				player.position = Vector2(centre,base+180)
		game.world.set_access_closed(id,false)
	await check_contact_pixels(game)
	check("map untouched",before==FileAccess.get_sha256("res://data/rooms/r04.json"))
	var failed: Array = checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"exterior-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
