extends "res://scripts/core/escape_game.gd"

func _ready() -> void:
	super._ready()
	guard.set_process(false)
	status_text = "环境验证：强力伙伴可顶住重箱。门的技能将在后续任务接入。"

func _process(delta: float) -> void:
	if phase == "playing":
		elapsed += delta
		orders.tick(delta)
		_update_ui()
		queue_redraw()

func reset_round(fixed_skills: Array = [], seed_value: int = -1) -> void:
	super.reset_round(fixed_skills,seed_value)
	if world:
		world.reset_world()

func snapshot() -> Dictionary:
	var result := super.snapshot()
	if world:
		result.world = world.snapshot()
	return result
