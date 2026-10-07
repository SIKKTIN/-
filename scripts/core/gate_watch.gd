extends RefCounted

const GateGuard = preload("res://scripts/actors/gate_guard.gd")
const ActorVisual = preload("res://scripts/presentation/actor_visual.gd")
var game
var guards: Array = []

func _init(owner_game) -> void:
	game = owner_game

func reset(config: Dictionary) -> void:
	for actor in guards:
		for visual in actor.get_children():
			game.presentation.visuals.erase(visual)
		actor.free()
	guards.clear()
	var base = game.presentation.visuals.filter(func(v): return v.actor == game.guard)[0]
	for spec in config.get("gate_guards",[]):
		var actor = GateGuard.new()
		actor.guard_id = str(spec.id)
		actor.post = Vector2(spec.position[0],spec.position[1])
		game.add_child(actor)
		actor.configure(game.world,game)
		attach_visual(actor,base)
		guards.append(actor)
		game.staff_traffic.register(actor,"gate",actor.post)
	tick(0)

func attach_visual(actor, base = null) -> void:
	if base == null:
		base = game.presentation.visuals.filter(func(v): return v.actor == game.guard)[0]
	actor.art_body = true
	actor.presentation_layers = game.perspective_floor
	var visual = ActorVisual.new()
	actor.add_child(visual)
	visual.configure(actor,game,base.definition.duplicate(true),game.presentation.skill_icons,game.presentation.font)
	visual.separate_information = game.perspective_floor
	visual.light_mask = 2
	game.presentation.visuals.append(visual)

func by_id(id: String):
	for actor in guards:
		if actor.guard_id == id:
			return actor
	return null

func blocking() -> bool:
	if game.staff_traffic and game.staff_traffic.factory_passage(): return false
	return guards.any(func(actor): return actor.blocking_gate())

func tick(delta: float) -> void:
	for actor in guards:
		actor.tick(delta)
	game.world.set_gate_guarded(blocking())

func snapshot() -> Array:
	return guards.map(func(actor): return {"id":actor.guard_id,"position":[actor.position.x,actor.position.y],"on_duty":actor.on_duty(),"blocking":actor.blocking_gate(),"chat_partner_id":actor.chat_partner_id,"state":actor.state})
