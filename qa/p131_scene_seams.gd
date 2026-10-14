extends "res://qa/p105_collision.gd"

func image_delta(a: Image, b: Image, region: Rect2) -> float:
	var origin: Vector2=game.get_canvas_transform()*region.position
	var pixels:=Rect2i(Vector2i(origin),Vector2i(region.size)).intersection(Rect2i(0,0,a.get_width(),a.get_height()))
	var changed:=0
	for y in range(pixels.position.y,pixels.end.y):
		for x in range(pixels.position.x,pixels.end.x):
			var first:=a.get_pixel(x,y)
			var second:=b.get_pixel(x,y)
			if absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)>0.06:changed+=1
	return float(changed)/maxi(1,pixels.size.x*pixels.size.y)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p131-seams.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","chat","backpack"],131)
	game.fullscreen_ui.fps_badge.hide()
	game.status_text=""
	game.world.admission_filter=Callable()
	await frame()
	await frame()
	var rules=game.room_visibility
	var bath: Dictionary=rules.rooms.filter(func(r):return r.id=="bath")[0]
	var clinic: Dictionary=rules.rooms.filter(func(r):return r.id=="clinic")[0]
	var bath_door: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-bath")[0]
	check("bath_corners_join_south_wall_coping",bath.roof_plan.roof.end.y==bath_door.rect.position.y-100)
	var clinic_door: Dictionary=game.world.fixtures.filter(func(f):return f.id=="campus-clinic")[0]
	check("rounded_clinic_corners_join_south_wall_coping",clinic.roof_plan.roof.end.y==clinic_door.rect.position.y-100)
	var roof=bath.roof_plan.panels
	check("bath_front_has_no_twenty_pixel_floor_strip",roof.any(func(r):return r.has_point(Vector2(bath.roof_plan.roof.position.x+40,bath.roof_plan.roof.end.y-10))))
	check("bath_front_meets_threshold_without_floor_nick",roof.any(func(r):return r.has_point(Vector2(bath_door.rect.position.x-10,bath.roof_plan.roof.end.y-1))))
	var missing: Array=[]
	var overlaps: Array=[]
	for fixture in game.world.fixtures:
		if not preload("res://scripts/presentation/doorway_geometry.gd").managed_fixture(fixture) or preload("res://scripts/presentation/doorway_geometry.gd").controlled_fixture(fixture):continue
		var port_id: String="fixture:"+str(fixture.id)
		var affected: Array=rules.rooms.filter(func(r):return r.roof_plan.ports.any(func(port):return port.id==port_id))
		if affected.is_empty():
			# Yard/outlet hardware is outdoors, outside every room perimeter.
			if rules.rooms.any(func(r):return r.area.grow(45).has_point(fixture.rect.get_center())):missing.append(port_id)
		for r in affected:
			var projected: Rect2=preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(game.world,{"rect":fixture.rect})
			if r.roof_plan.panels.any(func(panel):return panel.intersects(projected)):overlaps.append(port_id)
	check("ungated_room_doors_registered_with_roofs",missing.is_empty())
	check("roof_membranes_do_not_cover_authored_doors",overlaps.is_empty())
	var hard_floors: Array=game.room_config.floor_regions.filter(func(r):return not r.get("natural_ground",false))
	check("north_alcove_paving_covers_corridor_edge",hard_floors.any(func(r):return Rect2(r.rect[0],r.rect[1],r.rect[2],r.rect[3]).encloses(Rect2(120,220,580,300))))
	var builds: Array=rules.covers.map(func(c):return c.draw_builds)
	for i in range(30):game.presentation.tick(0)
	await frame()
	check("static_roofs_keep_retained_drawing_commands",rules.covers.map(func(c):return c.draw_builds)==builds)
	var differences: Dictionary={}
	if DisplayServer.get_name()!="headless":
		game.actors[0].position=Vector2(750,920)
		rules.tick(0,true)
		game.map_camera.center_on(game.actors[0].position)
		game.presentation.tick(0)
		game._update_ui()
		await frame()
		await frame()
		var actual:=root.get_texture().get_image()
		actual.save_png("res://docs/dev/p131/fixed-seams.png")
		var extra=rules.covers.filter(func(c):return c.room.id=="dorm-extra-0")[0]
		extra.hide()
		await frame()
		await frame()
		var without_side_roof:=root.get_texture().get_image()
		differences.side_door=image_delta(actual,without_side_roof,Rect2(682,706,16,84))
		check("native_upper_side_door_unobscured",differences.side_door<0.005)
		extra.show()
		var bath_cover=rules.covers.filter(func(c):return c.room.id=="bath")[0]
		game.map_camera.center_on(bath_cover.roof.get_center())
		game.map_camera.force_update_scroll()
		await frame()
		await frame()
		actual=root.get_texture().get_image()
		bath_cover.hide()
		await frame()
		await frame()
		var without_front_roof:=root.get_texture().get_image()
		differences.front_strip=image_delta(actual,without_front_roof,Rect2(bath_cover.roof.position.x+20,bath_cover.roof.end.y-12,bath_cover.roof.size.x-40,10))
		check("native_horizontal_gap_contains_roof",differences.front_strip>0.85)
		bath_cover.show()
		game.actors[0].position=Vector2(650,380)
		rules.tick(0,true)
		game.map_camera.center_on(game.actors[0].position)
		game.presentation.tick(0)
		game._update_ui()
		await frame()
		await frame()
		root.get_texture().get_image().save_png("res://docs/dev/p131/fixed-alcove.png")
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/tests/p131-scene-seams.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"unregistered_doors":missing,"covered_doors":overlaps,"native_pixel_differences":differences},"\t"))
	quit(0 if failed.is_empty() else 1)
