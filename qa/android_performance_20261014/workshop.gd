extends SceneTree
var game
var report: Dictionary={"cases":{}}
var tag: String="workshop-before"
func _initialize():call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func stats(values: Array)->Dictionary:
	var sorted:=values.duplicate();sorted.sort()
	return {"mean":values.reduce(func(a,b):return a+b,0.0)/values.size(),"p95":sorted[int(sorted.size()*0.95)],"max":sorted.back()}
func sample(label: String):
	for i in range(25):await frame()
	var times: Array=[];var draws: Array=[];var scripts: Array=[]
	var start:=Time.get_ticks_usec()
	for i in range(180):
		await frame()
		var now:=Time.get_ticks_usec();times.append((now-start)/1000.0);start=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		scripts.append(game.profile_total_ms)
	report.cases[label]={"frame_ms":stats(times),"draw_calls":stats(draws),"game_ms":stats(scripts)}
	print(label," ",JSON.stringify(report.cases[label]))
func freeze(node: Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	if not OS.get_cmdline_user_args().is_empty():tag=OS.get_cmdline_user_args()[0]
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_FRAME_MODE","0")
	OS.set_environment("ESCAPE_FRAME_SETTINGS_PATH","user://workshop-render-qa.cfg")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://workshop-render-qa.cfg")
	root.size=Vector2i(1600,720);root.content_scale_size=root.size
	game=preload("res://qa/android_performance_20261014/game.gd").new()
	game.room_id="r04";root.add_child(game)
	game.schedule.set_time_speed(0);game.actors[0].immune_until=INF;game.orders.stop(0)
	game.actors[0].position=Vector2(1500,1380)
	game.map_camera.center_on(game.actors[0].position);game.map_camera.following=false
	await sample("workshop_running")
	report.room=game.room_visibility.active_id
	freeze(game);game.profile_total_ms=0
	await sample("frozen_baseline")
	root.get_texture().get_image().save_png("res://docs/performance/android-frame-investigation-20261014/"+tag+".png")
	var shadows
	for layer in game.presentation.scene_layers:
		if layer.kind=="fixture_shadows":shadows=layer
	shadows.hide();await sample("without_fixture_shadows");shadows.show()
	var props: Array=[];var walls: Array=[]
	for volume in game.presentation.volumes:
		if not volume.visible:continue
		if volume.kind=="fixture":props.append(volume)
		elif volume.kind=="wall":walls.append(volume)
	for volume in props:volume.hide()
	await sample("without_fixtures")
	for volume in props:volume.show()
	for volume in walls:volume.hide()
	await sample("without_walls")
	for volume in walls:volume.show()
	game.presentation.lighting.sun.enabled=false
	await sample("without_sun")
	game.presentation.lighting.sun.enabled=true
	game.get_node("HUD").hide();await sample("without_hud")
	game.get_node("HUD").show()
	var shared:=ShaderMaterial.new()
	shared.shader=load("res://art/architecture/v24/opaque_core.gdshader")
	var shared_count:=0
	for volume in game.presentation.volumes:
		if volume.material is ShaderMaterial and volume.material.shader.resource_path==shared.shader.resource_path:
			volume.material=shared;shared_count+=1
		if volume.lintel_visual and volume.lintel_visual.material is ShaderMaterial and volume.lintel_visual.material.shader.resource_path==shared.shader.resource_path:
			volume.lintel_visual.material=shared;shared_count+=1
	report.shared_material_count=shared_count
	await sample("shared_uniform_free_material")
	report.renderer=RenderingServer.get_current_rendering_method()
	report.device=RenderingServer.get_video_adapter_name()
	report.scope="Windows GPU; fixed workshop view; frozen ablations isolate rendering, not Android FPS"
	FileAccess.open("res://docs/performance/android-frame-investigation-20261014/"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORKSHOP_DONE");game.queue_free();await frame();quit()
