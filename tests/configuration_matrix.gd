extends SceneTree

var game
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func skill_ids() -> Array:
	return game.actors.map(func(a): return a.skill_id)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var seeds := {}
	for seed_value in range(500):
		game.reset_round([],seed_value)
		seeds["/".join(skill_ids())] = seed_value
	var rows: Array = []
	var choices := ["chat","lockpick","strong"]
	for room in ["r01","r02"]:
		for a in choices:
			for b in choices:
				for c in choices:
					var config := [a,b,c]
					var key := "/".join(config)
					var seed_value: int = seeds.get(key,-1)
					game.load_room(room,[],seed_value)
					var first := skill_ids()
					var valid: bool = first == config and game.skills.actions.is_empty() and not game.world.door_open and game.world.lock_progress == 0 and game.captures == 0 and game.phase == "playing"
					for actor in game.actors:
						valid = valid and actor.position == actor.home and not actor.escaped
					game.reset_round([],seed_value)
					valid = valid and skill_ids() == first and seed_value >= 0
					var classification := "尚未证明"
					var evidence := "初始化与相同种子复现通过；尚无此有序配置的完整路线证据"
					if config == ["chat","chat","chat"]:
						classification = "规则判定无解"
						var no_path: bool = game.world.find_path(game.actors[0].position,Vector2(950,430)).is_empty()
						valid = valid and no_path
						evidence = "关闭的门和重箱阻断左右可行通路，导航无可行路径；聊天不能开门或推箱"
					elif room == "r01" and (config == ["lockpick","lockpick","lockpick"] or config == ["strong","strong","strong"]):
						classification = "已实测可解"
						evidence = "P05完整真实规则路线和原生实时运行：docs/dev/p05-route-result.json、p05-live-lock.json、p05-live-strong.json"
					elif room == "r02" and (config == ["chat","lockpick","strong"] or config == ["strong","strong","strong"]):
						classification = "已实测可解"
						evidence = "P06完整真实规则路线：docs/playtests/p06-r02-result.json；混合配置另有p06-live-r02.json"
					rows.append({"room":room,"skills":config,"seed":seed_value,"initialization_passed":valid,"classification":classification,"evidence":evidence})
					if not valid:
						failures.append({"room":room,"config":config,"actual":first,"seed":seed_value})
	var result := {"passed":failures.is_empty() and rows.size() == 54,"rows":rows,"failures":failures,"seed_version":"Godot 4.7.2 RNG","coverage":{"initializations":54,"ordered_configs_per_room":27,"tested_solvable":4,"rule_unsolvable":2,"not_proven":48},"note":"其他配置不因拥有开路技能而自动标记可解，路线、操作顺序与巡逻时机仍需实证。"}
	var file := FileAccess.open("res://docs/tests/p07-configuration-matrix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("P07_MATRIX ",JSON.stringify({"passed":result.passed,"coverage":result.coverage,"failures":failures}))
	quit(0 if result.passed else 1)
