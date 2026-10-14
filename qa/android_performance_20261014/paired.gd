extends SceneTree
const OldVolume=preload("res://docs/performance/android-frame-investigation-20261014/baseline/world_volume.gd")
const OldCards=preload("res://docs/performance/android-frame-investigation-20261014/baseline/keycard_service.gd")
const OldNine=preload("res://docs/performance/android-frame-investigation-20261014/baseline/nine_point_game.gd")
func _initialize():call_deferred("run")
func stats(a: Array)->Dictionary:
	var s:=a.duplicate();s.sort()
	return {"mean_ms":a.reduce(func(x,y):return x+y,0.0)/a.size(),"p95_ms":s[int(s.size()*0.95)]}
func pair(before: Callable,after: Callable)->Dictionary:
	var samples: Array=[[],[]]
	for i in range(60):
		for index in [i%2,1-i%2]:
			var operation: Callable=before if index==0 else after
			var start:=Time.get_ticks_usec()
			for j in range(5):operation.call()
			samples[index].append((Time.get_ticks_usec()-start)/5000.0)
	return {"before":stats(samples[0]),"after":stats(samples[1])}
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://android-frame-paired.cfg")
	var game=load("res://scripts/core/escape_game.gd").new();game.room_id="r04"
	root.add_child(game);await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	game.orders.stop(0);game.actors[0].position=Vector2(1500,1380)
	game.room_visibility.tick(0,true);game.presentation.tick(0)
	var old_cards=OldCards.new(game)
	old_cards.config=game.keycards.config;old_cards.room_by_id=game.keycards.room_by_id
	var old_nine=OldNine.new();old_nine.game=game
	var old_volumes: Array=[];var volumes: Array=[]
	for volume in game.presentation.volumes:
		if volume.kind!="fixture":continue
		var old=OldVolume.new();old.world=game.world;old.kind="fixture";old.wall_index=volume.wall_index
		old_volumes.append(old);volumes.append(volume)
	var before_visibility: Callable=func():
		for volume in old_volumes:volume._sync_visibility()
	var after_visibility: Callable=func():
		for volume in volumes:volume._sync_visibility()
	var before_nine: Callable=func():
		for fixture in old_nine.tables():old_nine.reason(str(fixture.id))
	var after_nine: Callable=func():
		for fixture in game.nine_point.tables():game.nine_point.reason(str(fixture.id))
	var report: Dictionary={"scope":"Alternating same-process Windows headless CPU comparison; not device FPS","fixture_visibility":pair(before_visibility,after_visibility),"keycard_tick":pair(old_cards.tick,game.keycards.tick),"card_table_search":pair(before_nine,after_nine)}
	for volume in old_volumes:volume.free()
	old_nine.free()
	FileAccess.open("res://docs/performance/android-frame-investigation-20261014/paired-cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.queue_free();await process_frame;quit()
