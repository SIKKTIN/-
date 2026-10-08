extends RefCounted

const MODES := [60,90,0]
var target_fps := 60
var preference_path := "user://frame-settings.cfg"

func configure() -> void:
	var override_path := OS.get_environment("ESCAPE_FRAME_SETTINGS_PATH")
	if override_path.begins_with("user://"): preference_path=override_path
	var saved := ConfigFile.new()
	if saved.load(preference_path)==OK:
		var value = saved.get_value("display","target_fps",60)
		if typeof(value)==TYPE_INT and value in MODES: target_fps=value
	var override_mode := OS.get_environment("ESCAPE_FRAME_MODE")
	if not override_mode.is_empty() and override_mode.is_valid_int() and int(override_mode) in MODES: target_fps=int(override_mode)
	apply(target_fps,false)

func apply(value: int, persist := true) -> bool:
	if value not in MODES: return false
	target_fps=value
	Engine.max_fps=target_fps
	# The explicit cap paces both 60 and 90 Hz modes independently of the
	# monitor's refresh rate. Physics and gameplay clock rates are unchanged.
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if persist:
		var saved := ConfigFile.new()
		saved.set_value("display","target_fps",target_fps)
		return saved.save(preference_path)==OK
	return true
