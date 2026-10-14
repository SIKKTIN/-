extends SceneTree
const OUT="res://docs/art/chess-activity-room-v1/"
var checks:Dictionary={}
var game
func _initialize():
	create_timer(150).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label:String,pass_value:bool):checks[label]=pass_value
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(label:String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+label+".png")
func stand(p:Vector2):
	game.actors[0].position=p;game.actors[0].moved_this_frame=false
	game.orders.clear();game.room_visibility.tick(0,true);game.presentation.tick(0);game.resident_staff.tick(0)
func minute(value:float):
	game.schedule.clock_elapsed=(value-480.0)/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
func contact_pixels():
	if DisplayServer.get_name()=="headless":return
	var gate:Dictionary=game.world.access_by_id("chess-entry")
	var player=game.actors[0]
	var visual=game.presentation.visuals[0]
	for closed in [false,true]:
		game.world.set_access_closed("chess-entry",closed)
		for side in [-1,1]:
			stand(Vector2(gate.rect.get_center().x+side*65,gate.rect.end.y+3.01))
			await frame();await frame()
			var actual:Image=root.get_texture().get_image()
			var depth:int=player.z_index
			player.z_index=game.room_visibility.doorways.by_id("chess-entry").z_index+10
			await frame()
			var reference:Image=root.get_texture().get_image()
			var area:Rect2=visual.get_global_transform_with_canvas()*visual.body_bounds()
			var differences:=0
			for y in range(maxi(0,floori(area.position.y)),mini(actual.get_height(),ceili(area.end.y))):
				for x in range(maxi(0,floori(area.position.x)),mini(actual.get_width(),ceili(area.end.x))):
					var d:=actual.get_pixel(x,y)-reference.get_pixel(x,y)
					if absf(d.r)+absf(d.g)+absf(d.b)>.03:differences+=1
			check("whole foreground body visible closed="+str(closed)+" side="+str(side),differences==0)
			player.z_index=depth
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://chess-v1-qa.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://chess-v1-qa-buttons.cfg")
	root.size=Vector2i(1400,950);root.content_scale_size=root.size;root.title="棋牌活动室验收"
	var disk:String=FileAccess.get_file_as_string("res://data/rooms/r04.json")
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restoration-input.json"))
	var latest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"refinement-input.json"))
	var after:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restoration-output.json"))
	var reg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"layout-registration.json"))
	var allowed:Array=["access_doors","architecture","walls","fixtures","zones","visibility_rooms","floor_regions","routine_points","resident_staff","chess_restoration_version"]
	for key in before:
		if key not in allowed:check("unrelated field "+key,before[key]==after[key])
	for group in ["zones","visibility_rooms","floor_regions","access_doors"]:
		check("existing "+group+" unchanged",before[group]==after[group].slice(0,before[group].size()))
	# Other chats can save unrelated buildings while production images generate.
	# Validate the latest saved furniture against the final targeted refinement.
	check("latest unrelated furniture unchanged",latest.fixtures.filter(func(f):return f.id not in reg.new_fixture_ids)==after.fixtures.filter(func(f):return f.id not in reg.new_fixture_ids))
	check("existing routines unchanged",before.routine_points.free==after.routine_points.free.slice(0,before.routine_points.free.size()))
	var old_walls:Array=[]
	for i in range(before.walls.size()):
		if float(i) not in reg.removed_wall_indices:old_walls.append(before.walls[i])
	check("other wall shapes unchanged",old_walls==after.walls.slice(0,old_walls.size()))
	var doc=preload("res://scripts/editor/map_document.gd").new()
	check("editor opens map",doc.open_file("res://data/rooms/r04.json"))
	check("editor validates map",doc.validate().errors.is_empty())
	var catalog=preload("res://scripts/editor/editor_catalog.gd").new()
	for id in ["chess_chess_table_v1","chess_card_table_v1","chess_stool_v1","chess_bench_v1","chess_cupboard_v1","chess_tea_v1","chess_bin_v1","chess_sign_v1","chess_corner_nw_v1","doorway_chess_open_v1"]:
		var entries:Array=catalog.entries.filter(func(e):return e.id==id)
		check(id+" palette entry",not entries.is_empty())
		check(id+" thumbnail",not entries.is_empty() and catalog.icon(entries[0])!=null)
	var artreg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
	for a in artreg.original_pngs:check(a.key+" original PNG hash",FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.schedule.set_time_speed(0)
	minute(1080)
	var actor=game.actors[0]
	var gate:Dictionary=game.world.access_by_id("chess-entry")
	var center:Vector2=gate.rect.get_center()
	var outside:=Vector2(1200,910)
	check("opens during day",not gate.closed)
	check("doorway path from south",not game.world.find_path(outside,Vector2(1320,690),actor,false,true).is_empty())
	check("room has correct footprint",game.room_visibility.rooms.any(func(r):return r.id=="chess-room" and r.area==Rect2(900,220,560,580)))
	for p in reg.free_points:
		var goal:=Vector2(p[0],p[1])
		check("free point clear "+str(p),game.world.can_place_circle(goal,game.ACTOR_RADIUS,actor,false))
		check("free point reachable "+str(p),not game.world.find_path(outside,goal,actor,false,true).is_empty())
	for p in [Vector2(1010,280),Vector2(1010,600),Vector2(1310,530),Vector2(1320,690)]:
		check("internal aisle "+str(p),game.world.can_place_circle(p,game.ACTOR_RADIUS,actor,false))
		check("internal route "+str(p),not game.world.find_path(outside,p,actor,false,true).is_empty())
	var room:Dictionary=game.room_visibility.rooms.filter(func(r):return r.id=="chess-room")[0]
	check("no neighboring room overlap",game.room_visibility.rooms.filter(func(r):return r.id!="chess-room").all(func(r):return not r.area.intersects(room.area)))
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id=="chess-room")[0]
	check("roof meets south coping",is_equal_approx(cover.roof.end.y,700))
	var volumes:Dictionary={}
	for v in game.presentation.volumes:
		if v.kind=="fixture":volumes[game.world.fixtures[v.wall_index].id]=v
	stand(Vector2(1330,645))
	check("interior reveals roof",not cover.visible)
	check("two table sprites visible",volumes["chess-table"].visible and volumes["chess-card-table"].visible)
	check("eight separate stools",game.world.fixtures.filter(func(f):return str(f.id).begins_with("chess-stool-")).size()==8)
	var furniture:Array=game.world.fixtures.filter(func(f):return str(f.id).begins_with("chess-") and f.get("blocks_movement",false))
	var overlaps:=false
	for i in range(furniture.size()):
		for j in range(i+1,furniture.size()):
			if furniture[i].rect.intersects(furniture[j].rect):overlaps=true
	check("furniture footprints do not overlap",not overlaps)
	for id in ["chess-table","chess-card-table"]:
		var v=volumes[id]
		check(id+" square proportion",absf(v.display_rect.size.x-v.display_rect.size.y)<20)
		check(id+" visual above ground",v.display_rect.position.y<v.footprint.position.y)
	stand(Vector2(1300,330))
	check("cupboard search registered",game.looting.containers.has("chess-cupboard"))
	check("cupboard accessible",game.looting.reason("chess-cupboard").is_empty())
	check("cashier moved back to bath",game.room_visibility.room_at(game.resident_staff.actors["bath-cashier"].position)=="bath")
	check("cashier stands clear",game.world.can_place_circle(game.resident_staff.actors["bath-cashier"].position,game.ACTOR_RADIUS,actor,false))
	game.actors[1].position=Vector2(1060,430);game.actors[2].position=Vector2(1310,435)
	stand(Vector2(1330,645));game.presentation.tick(0)
	game.get_node("HUD").hide();game.map_camera.center_on(Vector2(1180,485));game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	check("player visible inside",game.presentation.visuals[0].visible)
	check("companions visible inside",game.presentation.visuals[1].visible and game.presentation.visuals[2].visible)
	await shot("runtime-interior")
	for a in game.actors.slice(1):a.position=a.home
	stand(outside);check("outside restores roof",cover.visible)
	await shot("runtime-roof")
	var door=game.room_visibility.doorways.by_id("chess-entry")
	check("same frame open closed",door.open_patches[-1]==door.closed_patches[-1])
	for closed in [false,true]:
		game.world.set_access_closed("chess-entry",closed)
		for dy in [3.01,5,30,70]:
			for side in [-1,1]:
				var point:=Vector2(center.x+side*65,gate.rect.end.y+dy)
				check("no air wall "+str(closed)+" "+str(side)+" "+str(dy),game.world.can_place_circle(point,game.ACTOR_RADIUS,actor,false,false))
				stand(point);check("foreground depth "+str(closed)+" "+str(side)+" "+str(dy),actor.z_index>door.z_index)
	await contact_pixels()
	stand(outside);minute(1260)
	check("closed at night",gate.closed)
	check("closed leaf blocks entrance",not game.world.can_place_circle(center,game.ACTOR_RADIUS,actor,false))
	await shot("runtime-closed")
	check("QA did not overwrite map",disk==FileAccess.get_file_as_string("res://data/rooms/r04.json"))
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.canvas.zoom=.82;editor.canvas.origin=editor.canvas.size/2-Vector2(1190,490)*editor.canvas.zoom;editor.canvas.queue_redraw()
	await shot("editor-chess-room")
	check("editor shows latest map",editor.document.data==JSON.parse_string(disk))
	var failed:Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	editor.queue_free();await frame();quit(0 if failed.is_empty() else 1)
