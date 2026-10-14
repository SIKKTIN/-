extends SceneTree
const OUT="res://docs/art/south-laundry-bath-v01/"
var checks: Dictionary={}
var game
func _initialize():
	create_timer(120).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,value: bool):
	checks[label]=value
	if not value:print("FAIL: ",label)
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func by_id(items: Array) -> Dictionary:
	var result={}
	for item in items:result[item.id]=item
	return result
func normalized(data: Dictionary) -> Dictionary:
	var result=data.duplicate(true)
	result.fixtures=by_id(result.fixtures)
	return result
func restoration_data(data: Dictionary,reg: Dictionary) -> Dictionary:
	var walls=[]
	for s in data.architecture.wall_surfaces:
		if not s.get("south_life_generated",false):continue
		var copy: Dictionary=s.duplicate(true);copy.erase("wall_index")
		walls.append({"rect":data.walls[int(s.wall_index)],"surface":copy})
	return {"fixtures":by_id(data.fixtures.filter(func(f):return f.id in reg.changed_fixture_ids)),
		"gates":by_id(data.access_doors.filter(func(g):return g.id in reg.changed_gate_ids)),
		"rooms":by_id(data.visibility_rooms.filter(func(r):return r.id in ["bath","laundry"])),"walls":walls,"bath_service":data.bath_service}
func frame():
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func stand(point: Vector2):
	game.actors[0].position=point;game.actors[0].moved_this_frame=false
	game.orders.clear();game.skills.clear_all()
	game.room_visibility.tick(0,true);game.resident_staff.tick(0);game.presentation.tick(0)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://south-laundry-bath-qa.cfg")
	root.size=Vector2i(1500,960);root.content_scale_size=root.size
	var path="res://data/rooms/r04.json"
	var disk=FileAccess.get_sha256(path)
	var before=raw(OUT+"implementation-input-map.json")
	# Verify the authored patch against its own guarded input, while runtime
	# checks use the current saved map. Other chats may save unrelated rooms.
	var after=raw(OUT+"implementation-candidate-map.json")
	var initial_saved=raw(path)
	var reg=raw(OUT+"implementation-registration.json")
	var changed: Array=reg.changed_fixture_ids+reg.removed_fixture_ids
	check("unrelated furniture preserved",by_id(before.fixtures.filter(func(f):return f.id not in changed))==by_id(after.fixtures.filter(func(f):return f.id not in changed)))
	check("unrelated gate permissions preserved",before.access_doors.filter(func(g):return g.id not in reg.changed_gate_ids)==after.access_doors.filter(func(g):return g.id not in reg.changed_gate_ids))
	for k in before:
		if k not in ["fixtures","architecture","walls","floor_regions","visibility_rooms","zones","ground_details","access_doors","resident_staff","concept_plan"]:
			check("unrelated field preserved "+str(k),before[k]==after[k])
	var surfaces={}
	for s in after.architecture.wall_surfaces:surfaces[int(s.wall_index)]=s
	var walls_ok=true
	for s in before.architecture.wall_surfaces:
		var i=int(s.wall_index)
		if reg.removed_wall_indices.any(func(v):return int(v)==i):continue
		var n=int(reg.wall_index_remap[str(i)]);var copy: Dictionary=surfaces[n].duplicate(true);copy.wall_index=s.wall_index
		if before.walls[i]!=after.walls[n] or s!=copy:walls_ok=false
	check("unrelated wall geometry and shared junctions preserved",walls_ok)
	var assets=raw(OUT+"implementation-assets.json")
	for a in assets.assets:
		check("source PNG retained "+a.id,FileAccess.get_sha256(a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(3000,1500);game.dog.position=Vector2(3100,1500)
	var player=game.actors[0]
	game.schedule.clock_elapsed=(750.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false);game.room_access.tick()
	var laundry_out=Vector2(1390,3240);var laundry_in=Vector2(1390,3570)
	check("laundry north whole-body entrance both ways",game.world.motion_clear(laundry_out,laundry_in,player,false,true) and game.world.motion_clear(laundry_in,laundry_out,player,false,true))
	game.world.set_access_closed("cafeteria-rear",true)
	check("closed laundry north blocks whole body",not game.world.motion_clear(laundry_out,laundry_in,player,false,true))
	game.world.set_access_closed("cafeteria-rear",false)
	check("lunchtime access hours unchanged",float(game.world.access_by_id("cafeteria-rear").hours[0])==720 and float(game.world.access_by_id("cafeteria-rear").hours[1])==840)
	var bath_out=Vector2(2040,3240);var bath_in=Vector2(2040,3570)
	check("bath north whole-body entrance both ways",game.world.motion_clear(bath_out,bath_in,player,false,true) and game.world.motion_clear(bath_in,bath_out,player,false,true))
	for p in [Vector2(1610,4080),Vector2(2040,4080)]:
		check("southern wall closes old public exit "+str(p),not game.world.motion_clear(p+Vector2(0,-70),p+Vector2(0,100),player,false,true))
	check("bath east wall solid",not game.world.motion_clear(Vector2(2210,3650),Vector2(2340,3650),player,false,true))
	check("shared room wall solid",not game.world.motion_clear(Vector2(1730,3770),Vector2(1900,3770),player,false,true))
	check("perimeter remains solid",not game.world.motion_clear(Vector2(2040,4090),Vector2(2040,4270),player,false,true))
	check("west service lock linked identity preserved",game.world.access_by_id("laundry-equipment").linked_to=="maintenance-entry")
	game.world.set_access_closed("laundry-equipment",false)
	check("west service door passes after unlocking",game.world.motion_clear(Vector2(820,3730),Vector2(925,3730),player,false,true))
	game.world.set_access_closed("laundry-equipment",true)
	check("west service door locked collision",not game.world.motion_clear(Vector2(820,3730),Vector2(925,3730),player,false,true))
	var area_l=Rect2(900,3420,900,660);var area_b=Rect2(1840,3420,440,660)
	var furniture: Array=game.world.fixtures.filter(func(f):return (area_l.intersects(f.rect) or area_b.intersects(f.rect)) and f.blocks_movement and not str(f.asset_id).begins_with("doorway_"))
	var overlap=false
	for i in range(furniture.size()):
		var a: Dictionary=furniture[i]
		check("furniture remains inside its room "+a.id,area_l.encloses(a.rect) or area_b.encloses(a.rect))
		for j in range(i+1,furniture.size()):
			if a.rect.intersection(furniture[j].rect).get_area()>0.01:overlap=true
	check("no furniture footprint overlap",not overlap)
	var screen: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath-privacy-screen")[0]
	check("straight privacy screen attached to west wall",screen.rect.position.x==area_b.position.x and screen.rect.size==Vector2(140,18))
	check("clear central dry wet aisle",game.world.motion_clear(Vector2(2040,3550),Vector2(2040,3920),player,false,true))
	var bath=game.bath_service
	stand(bath.counter_point());game.inventory.wallet=30
	check("cashier moved into north reception",area_b.has_point(bath.cashier().position) and bath.cashier().position.y<3540)
	check("recharge point is free and reachable",game.world.can_place_circle(bath.counter_point(),8,player,false) and not game.world.find_path(bath_in,bath.counter_point(),player,false,true).is_empty())
	var recharge: Dictionary=bath.try_recharge(0,10)
	check("north counter issues water card",recharge.ok)
	var card: String=recharge.get("card_id","")
	bath.refresh_stations();check("six original shower IDs retained",bath.stations.size()==6)
	for id in bath.stations:
		var p: Vector2=bath.station_point(id)
		check("reachable shower "+id,not game.world.find_path(bath_in,p,player,false,true).is_empty())
		stand(p)
		var paid: Dictionary=bath.start_shower(0,id)
		check("water-card payment works "+id,paid.ok)
		bath.cancel(0)
	check("shower refunds original card",not card.is_empty() and bath.balance(card)==10)
	stand(bath.station_point("campus-bath-shower-0-0"));game.attributes.values[0].stamina=40
	if bath.start_shower(0,"campus-bath-shower-0-0").ok:bath.tick(6)
	check("shower completion restores stamina and charges once",game.attributes.values[0].stamina==60 and bath.balance(card)==8)
	var loot_ids=["laundry-cleaning-rack","laundry-clean-linen-shelf","laundry-dirty-sorting","laundry-folding-table","laundry-cart","campus-bath-locker-0"]
	for id in loot_ids:
		var f: Dictionary=game.world.fixtures.filter(func(f):return f.id==id)[0]
		var p: Vector2=f.rect.get_center()+Vector2(0,f.rect.size.y/2+25)
		check("search point reachable "+id,not game.world.find_path(bath_in if id.begins_with("campus-bath") else laundry_in,p,player,false,true).is_empty())
		stand(p);check("container can open "+id,game.looting.open(id));game.looting.tick(60)
		var state: Dictionary=game.looting.containers[id]
		if not state.ids.is_empty():
			var item: String=state.ids[0];var cell: Vector2i=state.layout[item].position
			check("container item to backpack "+id,game.looting.take(item).ok)
			check("item draggable back "+id,game.looting.move_item(item,"bag","source",cell).ok)
		game.looting.close()
	var covers=game.room_visibility.covers
	var l=covers.filter(func(c):return c.room.id=="laundry")[0];var b=covers.filter(func(c):return c.room.id=="bath")[0]
	stand(laundry_in);check("laundry roof hides independently",not l.visible and b.visible)
	stand(bath_in);check("bath roof hides independently",not b.visible and l.visible)
	stand(bath_out);check("both roofs opaque outside",l.visible and b.visible and l.modulate.a==1 and b.modulate.a==1)
	game.map_camera.zoom=Vector2(.85,.85);game.map_camera.position=Vector2(1590,3690)-Vector2(root.size)/.85/2;game.map_camera.force_update_scroll()
	await shot("runtime-roofs")
	game.world.set_access_closed("cafeteria-rear",true);game.room_visibility.doorways.tick(true);game.presentation.tick(0)
	await shot("runtime-north-closed")
	game.world.set_access_closed("cafeteria-rear",false)
	# Interior comparison sheet exposes both rooms only for this art screenshot.
	stand(laundry_in);b.hide();game.presentation.tick(0)
	for v in game.presentation.volumes:
		if v.kind=="fixture" and area_b.has_point(game.world.fixtures[v.wall_index].rect.get_center()):v.visible=true
	bath.cashier().visible=true
	await shot("runtime-interior")
	stand(bath_in)
	game.map_camera.zoom=Vector2(1.4,1.4);game.map_camera.position=Vector2(2060,3650)-Vector2(root.size)/1.4/2;game.map_camera.force_update_scroll()
	await shot("runtime-bath")
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame();await frame()
	editor.open_now(path);await frame()
	check("saved map validates in editor",editor.document.validate().errors.is_empty())
	for id in assets.definition_ids:
		check("asset available in palette "+id,editor.catalog.entries.any(func(a):return a.id==id))
		var texture: Texture2D=preload("res://scripts/presentation/world_texture.gd").load_asset(editor.canvas.definitions[id])
		check("bounded runtime texture "+id,texture!=null and maxf(texture.get_width(),texture.get_height())<=512)
	editor.canvas.zoom=.55;editor.canvas.origin=editor.canvas.size/2-Vector2(1590,3660)*.55;editor.canvas.queue_redraw()
	await shot("editor-layout")
	var rebuilds: int=editor.canvas.architecture_preview.full_refreshes
	var builds: int=editor.canvas.architecture_preview.doorways.geometry_builds
	for i in range(12):editor.canvas.origin+=Vector2(1,0);editor.canvas.queue_redraw();await frame()
	check("panning retains architecture cache",editor.canvas.architecture_preview.full_refreshes==rebuilds and editor.canvas.architecture_preview.doorways.geometry_builds==builds)
	check("QA leaves authored room data unchanged",restoration_data(raw(path),reg)==restoration_data(initial_saved,reg))
	var failures=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"implementation-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failures,"count":checks.size()},"\t"))
	print("South laundry/bath QA: ",checks.size()," checks; failures=",failures)
	quit(0 if failures.is_empty() else 1)
