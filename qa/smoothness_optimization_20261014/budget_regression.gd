extends SceneTree
class TestWorld extends RefCounted:
	var RADIUS:=18.0
	var ai_path_budget_active:=true
	var ai_path_spent_usec:=2000
	var obstacle_revision:=1
	var searches:=0
	var direct:=false
	func can_place_circle(_p,_r,_a,_avoid,_crate):return true
	func motion_clear(_from,_to,_actor,_avoid,_crate):return direct
	func find_path(_from,to,_actor,_avoid,_crate):
		searches+=1
		return PackedVector2Array([to])
	func move_actor(actor,offset,_push,_budget):actor.position+=offset;return offset
	func check_exit(_actor):return false
class TestActor extends Node2D:
	var escaped:=false
	var skill_id:="chat"
	var moved_this_frame:=false
	var facing:=Vector2.ZERO
class TestSkills extends RefCounted:
	func cancel(_id,_text):pass
class TestRoutine extends RefCounted:
	func take_control(_id):pass
	func preparing_afternoon():return false
class TestSchedule extends RefCounted:
	func preparing_for_work():return false
class TestGame extends RefCounted:
	var world=TestWorld.new()
	var skills=TestSkills.new()
	var routines=TestRoutine.new()
	var schedule=TestSchedule.new()
	var phase:="playing"
	var MOVE_SPEED:=260.0
	var actors: Array=[]
	var dialogue=null
	var attributes=null
	func actor_is_controllable(id):return id==0
	func show_status(_text,_duration=0):pass
func _initialize():
	var game=TestGame.new()
	for i in range(3):game.actors.append(TestActor.new())
	var orders=load("res://scripts/core/move_orders.gd").new(game)
	var checks: Dictionary={}
	checks.player_immediate=orders.issue(0,Vector2(200,0)) and game.world.searches==1 and not orders.active[0].path.is_empty()
	orders.stop(0)
	checks.npc_queued=orders.issue(1,Vector2(200,0),"room_exit") and game.world.searches==1 and orders.active[1].path.is_empty()
	orders.active[1].stalled=0.95
	orders.tick(0.2)
	checks.budget_wait_keeps_order=orders.active.has(1) and is_equal_approx(orders.active[1].stalled,0.95) and game.world.searches==1
	game.world.ai_path_spent_usec=0
	orders.tick(0.016)
	checks.pending_serviced_next_frame=game.world.searches==2 and not orders.active[1].path.is_empty() and game.actors[1].position.x>0
	checks.repeated_evacuation_reuses_route=orders.issue(1,Vector2(200,0),"routine") and game.world.searches==2 and orders.active[1].source=="routine"
	game.world.obstacle_revision+=1
	game.world.ai_path_spent_usec=0
	checks.geometry_change_replans=orders.issue(1,Vector2(200,0),"routine") and game.world.searches==3
	game.world.ai_path_spent_usec=2000;game.world.direct=true
	checks.clear_route_remains_immediate=orders.issue(2,Vector2(0,200),"room_exit") and not orders.active[2].path.is_empty() and game.world.searches==3
	game.world.direct=false
	orders.issue(0,Vector2(200,0))
	var old_count: int=game.world.searches
	orders.tick(0.016)
	checks.player_retries_not_deferred=game.world.searches>old_count
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	FileAccess.open("res://docs/dev/smoothness-optimization-2026-10-14/budget-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print("BUDGET "+JSON.stringify({"checks":checks,"failed":failed}))
	for actor in game.actors:actor.free()
	quit(0 if failed.is_empty() else 1)
