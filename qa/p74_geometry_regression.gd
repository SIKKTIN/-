extends SceneTree
const Warning=preload("res://scripts/presentation/guard_warning.gd")
class ProbeWorld extends RefCounted:
	var obstacle_revision:=1
	var crate:=Rect2(900,900,20,20)
	var rects: Array[Rect2]=[Rect2(300,100,30,330)]
	func sight_rects() -> Array[Rect2]: return rects
	func is_under_roof(_p: Vector2) -> bool: return false
class Probe extends Node2D:
	var world=ProbeWorld.new()
	var facing:=Vector2.RIGHT
	var state: String="patrol"
	func view_radius() -> float: return 160.0
	func search_zone() -> Rect2: return Rect2(0,0,512,512)
	func half_fov() -> float: return PI
	func alert_mode() -> bool: return false
var game
var checks := {}
func _initialize() -> void: call_deferred("run")
func brute(point: Vector2, radius: float, actor, actors: bool, crate: bool) -> bool:
	var world=game.world
	if actor in world.actors and world.admission_filter.is_valid() and not world.admission_filter.call(actor,point,radius): return false
	if actor!=null and actor.has_method("movement_allowed") and not actor.movement_allowed(point,radius): return false
	if not world.inside_room(point,radius): return false
	for rect in world.solid_rects(crate):
		if world._circle_hits_rect(point,radius,rect): return false
	if actors:
		for other in world.actors:
			if other==actor or other.escaped or point.distance_to(other.position)>=radius+17-0.01: continue
			if actor!=null and actor.position.distance_to(other.position)<radius+17 and point.distance_to(other.position)>actor.position.distance_to(other.position): continue
			return false
	return true
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	var rng:=RandomNumberGenerator.new()
	rng.seed=74
	var mismatches:=0
	var queries:=0
	for mode in [false,true]:
		game.world.planning_guard_doors=mode
		for i in range(5000):
			var point:=Vector2(rng.randf_range(70,3000),rng.randf_range(80,2340))
			var radius: float=[1.0,17.0,35.0][i%3]
			var actor=game.actors[i%3] if i%2 else null
			var a: bool=brute(point,radius,actor,i%4!=0,i%5!=0)
			var b: bool=game.world.can_place_circle(point,radius,actor,i%4!=0,i%5!=0)
			queries+=1
			if a!=b: mismatches+=1
	game.world.planning_guard_doors=false
	checks.spatial_10000_exact=mismatches==0
	# Cached indices invalidate when a door changes; the crate stays dynamic.
	var gate: Dictionary=game.world.access_by_id("cafeteria-entry")
	for closed in [false,true,false]:
		game.world.set_access_closed("cafeteria-entry",closed)
		checks["door_revision_"+str(closed)]=game.world.can_place_circle(gate.rect.get_center(),17,null,false)==brute(gate.rect.get_center(),17,null,false,true)
	game.world.crate.position+=Vector2(30,0)
	checks.moving_crate_immediate=not game.world.can_place_circle(game.world.crate.get_center(),17,null,false)
	var visual=game.presentation.visuals[0]
	visual.tick_visual(0.1,Rect2(Vector2(2400,1800),Vector2(400,400)))
	checks.offscreen_body_culled=not visual.visible
	visual.tick_visual(0.1,Rect2(game.actors[0].position-Vector2(100,100),Vector2(400,400)))
	checks.camera_returns_body=visual.visible
	# Render the actual GPU shader into a transparent isolated viewport.
	if DisplayServer.get_name()!="headless":
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(512,512)
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var probe=Probe.new()
		probe.position=Vector2(256,256)
		viewport.add_child(probe)
		var warning=Warning.new()
		viewport.add_child(warning)
		warning.configure(probe)
		warning.refresh(Rect2(0,0,512,512),true,true)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image=viewport.get_texture().get_image()
		var errors:=0
		var pixel_cases:=0
		for y in range(12,500,8):
			for x in range(12,500,8):
				var point:=Vector2(x+0.5,y+0.5)
				var distance: float=point.distance_to(probe.position)
				if absf(distance-160)<3 or absf(float(x)-300)<3: continue
				var hit: float=game.world.ray_rect_fraction(probe.position,point,probe.world.rects[0])
				var expected: bool=distance<160 and hit<0
				if (image.get_pixel(x,y).a>0.04)!=expected: errors+=1
				pixel_cases+=1
		checks.gpu_circle_wall_clip=errors==0
		checks.gpu_free_interior=image.get_pixel(200,256).a>0.08
		checks.gpu_behind_wall_hidden=image.get_pixel(400,256).a<0.01
		checks.gpu_boundary_visible=image.get_pixel(96,256).a>0.1
		var before: int=warning.geometry_updates
		warning.refresh(Rect2(0,0,512,512),true,true)
		checks.stationary_warning_retains_geometry=warning.geometry_updates==before
		probe.position.x+=10
		warning.refresh(Rect2(0,0,512,512),true,true)
		checks.warning_tracks_current_position=warning.position==probe.position and warning.geometry_updates>before
		warning.refresh(Rect2(900,900,100,100),true,true)
		checks.offscreen_warning_culled=not warning.visible
		image.save_png("res://docs/tests/p74-gpu-clip.png")
		checks["gpu_samples_"+str(pixel_cases)]=pixel_cases>3000
	# Dense editor layouts exceeding shader capacity use the original exact mesh.
	var original_sight: Array[Rect2]=game.world.cached_sight.duplicate()
	game.guard.position=Vector2(1600,1000)
	for id in range(65): game.world.cached_sight.append(Rect2(1630+id%4,1030+id/4,1,1))
	game.world.obstacle_revision+=1
	var dense_warning=Warning.new()
	game.add_child(dense_warning)
	dense_warning.configure(game.guard)
	dense_warning.refresh(game.world.bounds,true,true)
	checks.dense_map_uses_exact_fallback=dense_warning.use_fallback and dense_warning.fallback_mesh!=null
	game.world.cached_sight=original_sight
	game.world.obstacle_revision+=1
	dense_warning.refresh(game.world.bounds,true,true)
	checks.simple_map_returns_shader=not dense_warning.use_fallback
	if DisplayServer.get_name()!="headless":
		game.schedule.clock_elapsed=(1500.0-440)/1440*game.schedule.day_seconds
		game.schedule.tick(false)
		game.map_camera.center_on(Vector2(680,470))
		game.guard.position=Vector2(1700,1030)
		game.presentation.lighting.tick()
		checks.offscreen_night_light_disabled=not game.presentation.lighting.guard_light.enabled
		checks.offscreen_guard_keeps_detection=game.guard.sees(Vector2(1670,1030))
		var guard_origin: Vector2=game.guard.position
		game.guard.tick(0.1)
		checks.offscreen_guard_keeps_patrolling=game.guard.position.distance_to(guard_origin)>0.1
		game.map_camera.center_on(game.guard.position)
		game.presentation.lighting.tick()
		checks.light_returns_with_camera=game.presentation.lighting.guard_light.enabled
	var failed: Array=checks.keys().filter(func(k): return not checks[k])
	var report: Dictionary={"checks":checks,"failed":failed,"queries":queries,"mismatches":mismatches}
	FileAccess.open("res://docs/tests/p74-geometry-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
