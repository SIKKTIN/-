extends SceneTree
const OUT := "res://docs/art/departure-gate-v1/"
var checks := {}
var game
func _initialize() -> void:
	create_timer(90).timeout.connect(func():quit(124))
	call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func check(label: String, value: bool) -> void:
	checks[label]=value
	if not value:print("FAIL: ",label)
func shot(file: String) -> void:
	if game!=null and is_instance_valid(game):game.presentation.tick(0)
	await frame();await frame()
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+file+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://departure-gate-preview.cfg")
	root.size=Vector2i(1200,900);root.content_scale_size=root.size;Engine.max_fps=60
	var path := "res://data/rooms/r04.json"
	var sha := FileAccess.get_sha256(path)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
	var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var unrelated := true
	for key in before:
		if key not in ["fixtures","ground_details"] and before[key]!=after[key]:unrelated=false
	check("all unrelated map rules and architecture preserved",unrelated)
	check("other furniture preserved",before.fixtures.filter(func(f):return not f.get("primary_gate",false) and not f.get("departure_generated",false))==after.fixtures.filter(func(f):return not f.get("primary_gate",false) and not f.get("departure_generated",false)))
	check("other ground marks preserved",before.ground_details.filter(func(f):return not f.get("departure_generated",false))==after.ground_details.filter(func(f):return not f.get("departure_generated",false)))
	for a in JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json")).assets:
		check("original generated PNG preserved "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game)
	await frame();await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	game.guard.position=Vector2(2700,1500);game.dog.position=Vector2(2700,1550)
	var player=game.actors[0]
	player.position=Vector2(3460,700)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	var door=game.room_visibility.doorways.by_id("primary")
	check("primary uses two state textures",door.custom_texture!=null and door.closed_custom_texture!=null)
	check("primary logical gate unchanged",door.gate.rect==Rect2(3300,200,320,20))
	check("gate visual and passage registration agree",door.visual_rect==game.world.door_passage.portals.filter(func(p):return p.primary)[0].rect)
	check("new door aperture cuts obsolete wall lintels",game.room_visibility.portal_cuts.has(door.visual_rect))
	check("guards remain at authored posts",game.gate_watch.by_id("gate-watch-1").post==Vector2(3380,330) and game.gate_watch.by_id("gate-watch-2").post==Vector2(3560,330))
	game.world.door_open=false;game.world.set_gate_guarded(false);game.world._changed();door.refresh(true)
	check("closed primary blocks both crossing directions",not game.world.motion_clear(Vector2(3460,360),Vector2(3460,135),player,false,true) and not game.world.motion_clear(Vector2(3460,135),Vector2(3460,360),player,false,true))
	game.map_camera.zoom=Vector2(.94,.94)
	game.map_camera.position=Vector2(3460,450)-Vector2(root.size)/.94/2;game.map_camera.force_update_scroll()
	await shot("runtime-closed")
	game.world.open_door();door.refresh(true);game.presentation.tick(0)
	check("open primary permits both crossing directions",game.world.motion_clear(Vector2(3460,360),Vector2(3460,135),player,false,true) and game.world.motion_clear(Vector2(3460,135),Vector2(3460,360),player,false,true))
	check("main approach remains continuous",game.world.motion_clear(Vector2(3460,860),Vector2(3460,320),player,false,true))
	check("center aisle avoids new hard props",game.world.fixtures.filter(func(f):return f.get("departure_generated",false) and f.blocks_movement).all(func(f):return not f.rect.intersects(Rect2(3400,260,120,650))))
	game.world.set_gate_guarded(true)
	check("guard duty still blocks gate",not game.world.motion_clear(Vector2(3460,360),Vector2(3460,135),player,false,true))
	game.world.set_gate_guarded(false)
	player.position=Vector2(3460,130)
	check("original main escape trigger works",game.world.check_exit(player))
	player.escaped=false;player.position=Vector2(3460,650)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	await frame();await frame()
	var static_builds:int=game.presentation.scene_layers[0].static_ground.builds
	var door_builds:int=door.draw_builds
	for i in range(15):game.presentation.tick(0);await frame()
	check("static plaza drawings retained across frames",static_builds==game.presentation.scene_layers[0].static_ground.builds and door_builds==door.draw_builds)
	await shot("runtime-open")
	var rendered := {}
	for volume in game.presentation.volumes:
		if volume.kind!="fixture":continue
		var f: Dictionary=game.world.fixtures[volume.wall_index]
		if f.get("departure_generated",false):rendered[f.id]={"visible":volume.visible,"rect":str(volume.display_rect),"z":volume.z_index}
	FileAccess.open(OUT+"rendered-parts.json",FileAccess.WRITE).store_string(JSON.stringify(rendered,"\t"))
	game.queue_free();await frame()
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame()
	editor.open_now(path);await frame()
	var validation: Dictionary=editor.document.validate()
	check("map editor validation",validation.errors.is_empty())
	var baseline=preload("res://scripts/editor/map_document.gd").new()
	baseline.data=before
	check("checkpoint introduces no editor warnings",baseline.validate().warnings==validation.warnings)
	print("VALIDATION: ",JSON.stringify(validation))
	for a in JSON.parse_string(FileAccess.get_file_as_string("res://art/architecture/departure_gate_v1/manifest.json")).assets:
		check("editor palette includes "+a.id,editor.catalog.entries.any(func(v):return v.id==a.id))
		check("ready runtime resource "+a.id,preload("res://scripts/presentation/runtime_texture_store.gd").texture(a)!=null)
		if editor.canvas.textures.has(a.id):
			var t: Texture2D=editor.canvas.textures[a.id]
			check("bounded texture "+a.id,maxi(t.get_width(),t.get_height())<=512)
	check("editor primary art matches game",editor.canvas.architecture_preview.doorways.by_id("primary").custom_texture!=null)
	var adapter=preload("res://scripts/editor/preview_geometry.gd").new()
	for id in ["r01","r02","r03"]:
		adapter.update(JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/"+id+".json")),false)
		check("legacy primary geometry preserved "+id,preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(adapter,preload("res://scripts/presentation/doorway_geometry.gd").primary_spec(adapter))==preload("res://scripts/presentation/doorway_geometry.gd").projected_rect(adapter,{"rect":adapter.door}))
	editor.canvas.zoom=.57;editor.canvas.origin=editor.canvas.size/2-Vector2(3460,480)*editor.canvas.zoom
	editor.resource_search.text="外出大门";editor.rebuild_palette();editor.canvas.queue_redraw()
	await shot("editor-layout")
	check("verification does not save or change map",FileAccess.get_sha256(path)==sha)
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"departure_gate_checks":checks.size(),"failed":failed}))
	editor.queue_free();await frame()
	quit(0 if failed.is_empty() else 1)
