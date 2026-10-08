extends "res://scripts/core/escape_game.gd"
func _make_world():
 if not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0].begins_with("before-valid"):
  return load("res://qa/p87_profile_before_world.gd").new()
 return preload("res://qa/p87_profile_world.gd").new()
func capture_actor(_id: int) -> void:pass # QA-only: sustained pursuit, actual detection/movement retained.
