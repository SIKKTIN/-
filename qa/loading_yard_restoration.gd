extends SceneTree
const OUT := "res://docs/art/loading-yard-v02/"
var checks := {}
var game
func _initialize() -> void: call_deferred("run")
func frame() -> void:
    await process_frame
    if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func check(label: String, value: bool) -> void:
    checks[label]=value
    if not value: print("FAIL: ",label)
func shot(name: String) -> void:
    await frame()
    await frame()
    if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
    OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
    OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://loading-yard-qa.cfg")
    root.size=Vector2i(1000,2400)
    root.content_scale_size=root.size
    var path := "res://data/rooms/r04.json"
    var disk := FileAccess.get_sha256(path)
    var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"last-input-map.json"))
    var after: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var reg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"map-registration.json"))
    var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"asset-registration.json"))
    var unrelated := true
    for k in before:
        if k not in ["fixtures","floor_regions","zones","ground_details","access_doors","gate_guards","loading_restoration_version"] and before[k]!=after[k]:unrelated=false
    check("all unrelated map fields and wall geometry preserved",unrelated)
    check("other furniture preserved",before.fixtures.filter(func(f):return f.id not in reg.fixture_ids and f.id not in reg.gate_fixture_ids and not f.get("loading_generated",false))==after.fixtures.filter(func(f):return f.id not in reg.fixture_ids and f.id not in reg.gate_fixture_ids and not f.get("loading_generated",false)))
    check("other floors preserved",before.floor_regions.filter(func(v):return v.id not in reg.floor_ids)==after.floor_regions.filter(func(v):return v.id not in reg.floor_ids))
    check("other zone labels preserved",before.zones.filter(func(v):return v.id!="loading")==after.zones.filter(func(v):return v.id!="loading"))
    check("other ground paint preserved",before.ground_details.filter(func(v):return not in_yard(v))==after.ground_details.filter(func(v):return not in_yard(v)))
    check("NPC count preserved",before.gate_guards.size()==after.gate_guards.size())
    for i in before.gate_guards.size():
        var old: Dictionary=before.gate_guards[i].duplicate(true)
        var now: Dictionary=after.gate_guards[i].duplicate(true)
        if old.id=="loading-watch":old.erase("patrol");now.erase("patrol")
        check("NPC data preserved "+str(old.id),old==now)
    for i in before.access_doors.size():
        var old: Dictionary=before.access_doors[i].duplicate(true)
        var now: Dictionary=after.access_doors[i].duplicate(true)
        for k in ["asset_id","rotation_door_visual_rect","door_art_size","label_offset"]:old.erase(k);now.erase(k)
        check("gate rules and collision preserved "+str(old.id),old==now)
    for id in reg.containers:check("container retained "+id,after.fixtures.any(func(v):return v.id==id and v.get("loot_profile","")==reg.containers[id]))
    var fixture_ids: Dictionary={}
    for f in after.fixtures:fixture_ids[f.id]=true
    check("no duplicate fixture IDs",fixture_ids.size()==after.fixtures.size())
    for a in record.assets:check("generated PNG preserved "+a.key,FileAccess.get_sha256("res://"+a.path)==a.sha256)
    game=load("res://scenes/main.tscn").instantiate()
    game.room_id="r04"
    root.add_child(game)
    await frame()
    game.set_process(false)
    game.fullscreen_ui.set_process(false)
    game.get_node("HUD").hide()
    var player=game.actors[0]
    var center := Vector2(5440,2100)
    player.position=center
    game.room_visibility.tick(0,true)
    game.presentation.tick(0)
    check("loading yard has no room roof",game.room_visibility.covers.all(func(v):return v.room.id!="loading"))
    check("body scale unchanged",preload("res://scripts/core/world_scale.gd").HUMAN==1.4)
    var fixtures: Array=game.world.fixtures.filter(func(v):return v.get("loading_generated",false))
    var area := Rect2(5140,220,660,3340)
    var overlap := false
    for i in fixtures.size():
        var f: Dictionary=fixtures[i]
        if not f.blocks_movement:continue
        var allowed := Rect2(5140,220,660,4020) if f.id.begins_with("loading-bollard-") else area
        check("footprint stays in yard "+f.id,allowed.encloses(f.rect))
        for j in range(i+1,fixtures.size()):
            var b: Dictionary=fixtures[j]
            if b.blocks_movement and f.rect.intersection(b.rect).get_area()>.01:overlap=true;print("Overlap ",f.id," / ",b.id)
    check("cargo and vehicle footprints do not overlap",not overlap)
    check("full body central aisle continuous",game.world.motion_clear(Vector2(5440,470),Vector2(5440,3460),player,false,true))
    for y in [600,1800,2900,3410]:check("east boundary closed "+str(y),not game.world.motion_clear(Vector2(5750,y),Vector2(5860,y),player,false,true))
    for side in ["east-north","east-south"]:
        var id: String="fixture:campus-warehouse-"+side
        var gate: Dictionary=game.world.door_passage.by_id(id)
        var y: float=gate.rect.get_center().y+35
        var pair := [Vector2(4960,y),Vector2(5380,y)]
        check("warehouse two way full body crossing "+side,game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true))
        check("warehouse entrance reaches aisle "+side,not game.world.find_path(center,pair[0],player,false,true).is_empty())
    var crossings := {"loading-exit":[Vector2(5600,40),Vector2(5600,340)],"service-barrier":[Vector2(5390,3440),Vector2(5390,3760)],"rear-exit":[Vector2(5660,3980),Vector2(5660,4360)]}
    for id in crossings:
        var gate: Dictionary=game.world.access_by_id(id)
        var door=game.room_visibility.doorways.by_id(id)
        var pair: Array=crossings[id]
        check("retained state driven gate sprite "+id,door.custom_texture!=null and door.closed_custom_texture!=null and door.visual_rect.size.y==120)
        check("gate label clears new facade "+id,float(gate.label_offset[1])>door.visual_rect.size.y/2+15)
        gate.closed=true;game.world._changed();door.refresh(true)
        check("closed gate blocks whole body "+id,not game.world.motion_clear(pair[0],pair[1],player,false,true))
        gate.closed=false;game.world._changed();door.refresh(true)
        check("open gate permits both directions "+id,game.world.motion_clear(pair[0],pair[1],player,false,true) and game.world.motion_clear(pair[1],pair[0],player,false,true))
        gate.closed=true;game.world._changed();door.refresh(true)
    var watch=game.gate_watch.by_id("loading-watch")
    for p in watch.regional_patrol:check("clear guard patrol "+str(p),not game.world.find_path(center,p,watch,false,true).is_empty())
    var points := {}
    for f in fixtures:
        if not f.has("loot_profile"):continue
        var r: Rect2=f.rect
        var candidates := [Vector2(r.end.x+35,r.get_center().y+30),Vector2(r.position.x-35,r.get_center().y+30),Vector2(r.get_center().x,r.end.y+35),Vector2(r.get_center().x,r.position.y-35)]
        var found := false
        for p in candidates:
            if not area.has_point(p) or game.world.find_path(center,p,player,false,true).is_empty():continue
            player.position=p;game.room_visibility.tick(0,true)
            if game.looting.reason(f.id).is_empty():points[f.id]=p;found=true;break
        check("storage reachable and searchable "+f.id,found)
    var sample := "cargo-pallet-2"
    if points.has(sample):
        player.position=points[sample];game.room_visibility.tick(0,true)
        check("cargo search opens",game.looting.open(sample))
        game.looting.tick(60)
        var loot: Dictionary=game.looting.containers[sample]
        check("cargo reveals supplies",not loot.ids.is_empty())
        if not loot.ids.is_empty():
            var item: String=loot.ids[0]
            var cell: Vector2i=loot.layout[item].position
            check("cargo moves into bag",game.looting.take(item).ok)
            check("cargo drags back into source",game.looting.move_item(item,"bag","source",cell).ok)
        game.looting.close()
    player.position=center;game.room_visibility.tick(0,true)
    game.map_camera.zoom=Vector2(.55,.55)
    game.map_camera.position=Vector2(5430,2150)-Vector2(root.size)/game.map_camera.zoom/2
    game.map_camera.force_update_scroll()
    game.presentation.tick(0)
    await frame()
    var durations: Array=[]
    var start := Time.get_ticks_usec()
    var builds: int=game.presentation.scene_layers[0].static_ground.builds
    for i in range(90):
        game.presentation.tick(0)
        durations.append(Time.get_ticks_usec()-start)
        start=Time.get_ticks_usec()
        await frame()
    check("static markings cached across frames",builds==game.presentation.scene_layers[0].static_ground.builds)
    FileAccess.open(OUT+"after-performance.json",FileAccess.WRITE).store_string(JSON.stringify({"viewport":[1000,2400],"zoom":.55,"frame_us":durations,"static_builds":builds},"\t"))
    root.size=Vector2i(650,2400);root.content_scale_size=root.size
    game.map_camera.position=Vector2(5480,2150)-Vector2(root.size)/game.map_camera.zoom/2
    game.map_camera.force_update_scroll()
    game.presentation.tick(0)
    await shot("runtime-after")
    root.size=Vector2i(1200,720);root.content_scale_size=root.size
    game.map_camera.zoom=Vector2.ONE
    game.map_camera.center_on(Vector2(5480,1410));game.map_camera.force_update_scroll()
    await shot("runtime-truck")
    game.map_camera.center_on(Vector2(5480,410));game.map_camera.force_update_scroll()
    await shot("runtime-logistics-gate")
    game.world.access_by_id("loading-exit").closed=false
    game.world._changed()
    game.room_visibility.doorways.tick(true)
    game.presentation.tick(0)
    for layer in game.presentation.scene_layers:layer.queue_redraw()
    await shot("runtime-logistics-open")
    game.queue_free();await frame()
    root.size=Vector2i(1280,800);root.content_scale_size=root.size
    var editor=load("res://scenes/editor/map_editor.tscn").instantiate()
    root.add_child(editor);await frame()
    editor.open_now(path);await frame()
    check("editor map validation",editor.document.validate().errors.is_empty())
    for asset in record.definition_ids:
        check("palette has asset "+asset,editor.catalog.entries.any(func(v):return v.id==asset))
        if editor.canvas.textures.has(asset):
            var texture: Texture2D=editor.canvas.textures[asset]
            check("bounded runtime texture "+asset,maxi(texture.get_width(),texture.get_height())<=1024)
    var index: int=editor.document.data.fixtures.find(editor.document.data.fixtures.filter(func(v):return v.id=="loading-truck")[0])
    var ref := {"group":"fixtures","index":index}
    var original: Dictionary=editor.document.data.fixtures[index].duplicate(true)
    editor.document.mirror_fixture(ref,true)
    check("truck mirror edits data",editor.document.data.fixtures[index]!=original)
    editor.document.undo()
    check("truck mirror undo",editor.document.data.fixtures[index]==original)
    var transform=preload("res://scripts/editor/map_transform.gd")
    var snapshot: Dictionary=transform.capture(editor.document,[ref],false)
    editor.document.begin();transform.apply(editor.document,snapshot,1);editor.document.commit()
    check("truck rotates ground bounds",editor.document.data.fixtures[index].rect[2]==original.rect[3])
    editor.document.undo()
    check("truck rotation undo",editor.document.data.fixtures[index]==original)
    editor.canvas.zoom=.14
    editor.canvas.origin=editor.canvas.size/2-Vector2(5460,2160)*editor.canvas.zoom
    editor.resource_search.text="装卸场";editor.rebuild_palette()
    editor.layers.set_visible("actors",false)
    editor.layers.set_visible("items",false)
    editor.canvas.queue_redraw()
    await shot("editor-layout")
    check("QA leaves saved map intact",FileAccess.get_sha256(path)==disk)
    var failed: Array=checks.keys().filter(func(label):return not checks[label])
    FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
    print(JSON.stringify({"loading_yard_checks":checks.size(),"failed":failed}))
    editor.queue_free();await frame()
    quit(0 if failed.is_empty() else 1)
func in_yard(v: Dictionary) -> bool:
    if v.get("loading_generated",false):return true
    var p: Array=v.get("position",v.get("from",v.get("rect",[-1,-1])))
    return 5140<=p[0] and p[0]<5800 and 200<=p[1] and p[1]<3560

