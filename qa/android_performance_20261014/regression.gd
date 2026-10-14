extends SceneTree
const OldVolume=preload("res://docs/performance/android-frame-investigation-20261014/baseline/world_volume.gd")
func _initialize():call_deferred("run")
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://android-frame-regression.cfg")
	var game=load("res://scripts/core/escape_game.gd").new()
	game.room_id="r04";root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var mismatches: Array=[];var compared:=0
	var old=OldVolume.new();old.world=game.world;old.kind="fixture"
	var rules=game.room_visibility
	var rooms: Array=[""]
	for room in rules.rooms:rooms.append(str(room.id))
	for room_id in rooms:
		rules.active_id=room_id;rules._current_areas.clear();rules._hidden_areas.clear()
		for room in rules.rooms:
			if str(room.id)==room_id:rules._current_areas.assign(room.areas)
			else:rules._hidden_areas.append_array(room.areas)
		rules.revision+=1
		game.presentation._tick_scene()
		for volume in game.presentation.volumes:
			if volume.kind!="fixture":continue
			old.wall_index=volume.wall_index
			old._sync_visibility();compared+=1
			if old.visible!=volume.visible:mismatches.append([room_id,volume.wall_index])
	old.free()
	var expected: Array=game.world.fixtures.filter(func(f):return str(f.get("asset_id",""))=="chess_card_table_v1")
	var cache_ok: bool=game.nine_point.tables()==expected
	var returned: Array=game.nine_point.tables();returned.clear()
	cache_ok=cache_ok and game.nine_point.tables()==expected
	var fixture: Dictionary={"id":"qa-added-table","asset_id":"chess_card_table_v1"}
	game.world.fixtures.append(fixture);game.world.fixtures_revision+=1
	cache_ok=cache_ok and game.nine_point.tables().has(fixture)
	game.world.fixtures.pop_back();game.world.fixtures_revision+=1
	cache_ok=cache_ok and game.nine_point.tables()==expected
	var report: Dictionary={"visibility_comparisons":compared,"mismatches":mismatches,"table_cache_rebuild_and_return_isolation":cache_ok}
	FileAccess.open("res://docs/performance/android-frame-investigation-20261014/regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.queue_free();await process_frame
	quit(0 if mismatches.is_empty() and cache_ok else 1)
