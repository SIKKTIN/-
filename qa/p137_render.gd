extends "res://qa/p105_collision.gd"

# The pre-optimization drawing order, kept only as a native image reference.
class ReferenceGround extends Node2D:
	var game
	func _draw():
		var world=game.world
		var presentation=game.presentation
		var sources: Dictionary={}
		for volume in presentation.volumes:
			if not sources.has(volume.footprint):sources[volume.footprint]=volume
		preload("res://scripts/presentation/site_details.gd").paint(self,game.room_config.get("ground_details",[]))
		for zone in game.room_config.get("zones",[]):
			var values: Array=zone.rect
			var tint:=Color(zone.color)
			tint.a=0.13
			draw_rect(Rect2(values[0],values[1],values[2],values[3]).intersection(world.bounds),tint)
		for wall in world.walls:
			var volume=sources.get(wall)
			if volume==null:continue
			var id: String=volume.prop_id() if volume.kind!="wall" else volume.asset_id("wall_top","low_wall_top_v02")
			if not presentation.asset_definitions.get(id,{}).get("shadow_baked",false):
				preload("res://scripts/presentation/soft_shadow.gd").contact_rect(self,wall,volume.elevation,world.bounds,presentation.profile)

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p129-regression.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","chat","backpack"],129)
	game.fullscreen_ui.fps_badge.hide()
	game.actors[0].position=Vector2(430,1450)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	game.presentation.tick(0)
	game._update_ui()
	await frame()
	await frame()
	var layer=game.presentation.scene_layers.filter(func(l):return l.kind=="ground_static")[0]
	var builds: int=layer.static_ground.builds
	for i in range(40):
		game.map_camera.position+=Vector2(1,0)
		game.presentation.tick(0)
	await frame()
	check("camera_motion_keeps_retained_static_geometry",layer.static_ground.builds==builds)
	var missing:=0
	var rng:=RandomNumberGenerator.new()
	rng.seed=129
	for i in range(1000):
		var point:=Vector2(rng.randf_range(0,6000),rng.randf_range(0,4500))
		var ids: Array=game.looting.nearby_ids(point)
		for id in game.looting.containers:
			var rect: Rect2=game.looting.containers[id].fixture.rect
			if point.distance_to(point.clamp(rect.position,rect.end))<=72 and not ids.has(id):missing+=1
	check("container_index_matches_exact_range_at_1000_points",missing==0)
	var id: String="detail44-dorm-personal-0"
	game.actors[0].position=game.looting.containers[id].fixture.rect.end+Vector2(12,5)
	game.room_visibility.tick(0,true)
	game.looting.open(id)
	game.looting.tick(30)
	var ui=game.looting.panel
	var source_builds: int=ui.view_model.source_builds
	var bag_builds: int=ui.view_model.bag_builds
	for i in range(60):ui.refresh()
	check("idle_search_does_not_rebuild_item_data",source_builds==ui.view_model.source_builds and bag_builds==ui.view_model.bag_builds)
	game.looting.close()
	var lamps: Array=game.presentation.lighting.lamps.duplicate()
	for i in range(30):game.presentation.lighting.tick()
	check("unchanged_lights_keep_existing_resources",game.presentation.lighting.lamps==lamps)
	game.actors[0].position=Vector2(430,1450)
	game.room_visibility.tick(0,true)
	game.map_camera.center_on(game.actors[0].position)
	game.presentation.tick(0)
	game._update_ui()
	var differences: Dictionary={}
	if DisplayServer.get_name()!="headless":
		var reference:=ReferenceGround.new()
		reference.game=game
		reference.z_index=layer.z_index
		game.add_child(reference)
		game.move_child(reference,layer.get_index())
		for spot in [Vector2(430,1450),Vector2(1650,1250),Vector2(3250,2720)]:
			game.map_camera.center_on(spot)
			game.presentation.tick(0)
			reference.hide()
			layer.show()
			await frame()
			await frame()
			var actual=root.get_texture().get_image()
			actual.save_png("res://docs/dev/p137/render/optimized-"+str(int(spot.x))+".png")
			layer.hide()
			reference.show()
			await frame()
			await frame()
			var expected=root.get_texture().get_image()
			expected.save_png("res://docs/dev/p137/render/reference-"+str(int(spot.x))+".png")
			var changed:=0
			for y in range(720):
				for x in range(1200):
					var a:=actual.get_pixel(x,y)
					var b:=expected.get_pixel(x,y)
					if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>0.035:changed+=1
			differences[str(int(spot.x))]=changed
			check("static_render_preserves_appearance_"+str(int(spot.x)),changed<1200*720*0.002)
		reference.free()
		layer.show()
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/dev/p137/render-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"changed_pixels":differences},"\t"))
	quit(0 if failed.is_empty() else 1)
