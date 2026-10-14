extends RefCounted

const Visual = preload("res://scripts/presentation/resident_staff_visual.gd")
var game
var actors: Dictionary = {}

func _init(owner_game) -> void:
	game = owner_game
	reset()

func reset() -> void:
	for actor in actors.values(): actor.free()
	actors.clear()
	for spec in game.room_config.get("resident_staff",[]):
		var actor = Visual.new()
		game.add_child(actor)
		actor.configure(game,spec)
		actors[str(spec.id)] = actor

func tick(delta: float) -> void:
	for actor in actors.values(): actor.tick(delta)

func snapshot() -> Dictionary:
	var result := {}
	for id in actors: result[id] = actors[id].snapshot()
	return result
