extends SceneTree
const OUT="res://docs/art/cafeteria-north-wall-v3/"
const DoorGeometry=preload("res://scripts/presentation/doorway_geometry.gd")
var game
var checks={}
func _initialize():
	create_timer(90).timeout.connect(func():quit(124))
	call_deferred("run")
func check(label: String,ok: bool):
	checks[label]=ok
	if not ok:print("FAIL: ",label)
func frame():
	await process_frame;await RenderingServer.frame_post_draw
func shot(name: String):
	await frame();await frame();root.get_texture().get_image().save_png(OUT+name+".png")
func raw(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var baseline="before" in OS.get_cmdline_user_args()
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://cafeteria-north-wall-qa.cfg")
	root.size=Vector2i(1400,1000);root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate();game.room_id="r04";root.add_child(game);await frame()
	game.set_process(false);game.fullscreen_ui.set_process(false);game.get_node("HUD").hide()
	var room: Dictionary=game.room_visibility.rooms.filter(func(r):return r.name=="食堂")[0]
	var cover=game.room_visibility.covers.filter(func(c):return c.room.id==room.id)[0]
	var gates=["cafeteria-entry","cafeteria-entry-east"]
	var geometry={"doors":{},"roof":[cover.roof.position.x,cover.roof.position.y,cover.roof.size.x,cover.roof.size.y],"room_rect":room.rect}
	var player=game.actors[0]
	for actor in game.world.actors:
		if actor!=player:actor.position=Vector2(3000,1200)
	game.world.crate.position=Vector2(3100,1200)
	for id in gates:
		var gate: Dictionary=game.world.access_by_id(id)
		var rect: Rect2=DoorGeometry.projected_rect(game.world,gate)
		geometry.doors[id]=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
		var point: Vector2=gate.rect.get_center()
		game.world.set_access_closed(id,false);game.room_visibility.doorways.tick(true)
		check("open doorway body passes "+id,game.world.motion_clear(point-Vector2(0,160),point+Vector2(0,130),player,false,true))
		player.position=point-Vector2(0,160)
		game.world.set_access_closed(id,true);game.room_visibility.doorways.tick(true)
		check("closed doorway body blocks "+id,not game.world.motion_clear(point-Vector2(0,160),point+Vector2(0,130),player,false,true))
	player.position=room.area.get_center();game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("interior roof hides",not cover.visible)
	game.map_camera.zoom=Vector2.ONE*.98
	game.map_camera.center_on(Vector2(room.area.get_center().x,2170));game.map_camera.force_update_scroll()
	await shot("runtime-interior-"+("before" if baseline else "after"))
	for id in gates:game.world.set_access_closed(id,false)
	game.room_visibility.doorways.tick(true);game.presentation.tick(0)
	await shot("runtime-open-"+("before" if baseline else "after"))
	player.position=room.area.position-Vector2(0,200);game.room_visibility.tick(0,true);game.presentation.tick(0)
	check("exterior roof restores",cover.visible and cover.modulate.a==1)
	await shot("runtime-exterior-"+("before" if baseline else "after"))
	if baseline:
		FileAccess.open(OUT+"geometry-before.json",FileAccess.WRITE).store_string(JSON.stringify(geometry,"\t"))
	else:
		var before_geometry=raw(OUT+"geometry-before.json")
		FileAccess.open(OUT+"geometry-after.json",FileAccess.WRITE).store_string(JSON.stringify(geometry,"\t"))
		print("Door art comparison: ",geometry.doors," baseline=",before_geometry.doors)
		check("door art bounds preserved",geometry.doors==before_geometry.doors)
		check("room reveal region preserved",geometry.room_rect==before_geometry.room_rect)
		for id in gates:
			var header=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].id==id+"-stone-header-v3")[0]
			check("door coping aligns with wall "+id,header.display_rect.position.y==cover.roof.position.y and header.display_rect.size.y==20)
		var before=raw(OUT+"map-before.json");var after=raw(OUT+"map-after.json")
		var permission_specs: Array=after.access_doors.duplicate(true)
		for gate in permission_specs:
			if gate.id in gates:gate.erase("rotation_door_visual_rect")
		check("access permissions unchanged",before.access_doors==permission_specs)
		for key in before:
			if key not in ["architecture","walls","fixtures","access_doors"]:check("map field unchanged "+str(key),before[key]==after[key])
		var registration=raw(OUT+"registration.json")
		check("unrelated fixtures preserved",before.fixtures.filter(func(f):return f.id not in registration.changed_fixture_ids)==after.fixtures.filter(func(f):return f.id not in registration.changed_fixture_ids))
		for i in registration.wall_indices:
			var old: Array=before.walls[int(i)];var new: Array=after.walls[int(i)]
			check("wall foot position preserved "+str(i),old[1]+old[3]==new[1]+new[3])
	game.queue_free();await frame()
	var editor=load("res://scenes/editor/map_editor.tscn").instantiate();root.add_child(editor);await frame()
	editor.open_now("res://data/rooms/r04.json");await frame()
	check("editor validates saved map",editor.document.validate().errors.is_empty())
	editor.canvas.zoom=.7;editor.canvas.origin=editor.canvas.size/2-Vector2(1500,2150)*.7;editor.canvas.queue_redraw()
	await shot("editor-"+("before" if baseline else "after"))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open(OUT+("checks-before.json" if baseline else "checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"\t"))
	print("Cafeteria north wall: ",checks.size()," checks; failures=",failed)
	quit(0 if failed.is_empty() else 1)
