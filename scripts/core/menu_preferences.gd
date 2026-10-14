extends RefCounted

# Player-facing audio/window preferences. FrameSettings owns its own preset.
var volume := 1.0
var fullscreen := false
var preference_path := "user://menu-settings.cfg"

func configure() -> void:
	var override_path := OS.get_environment("ESCAPE_MENU_SETTINGS_PATH")
	if override_path.begins_with("user://"): preference_path = override_path
	var saved := ConfigFile.new()
	if saved.load(preference_path) == OK:
		var stored_volume = saved.get_value("audio", "volume", 1.0)
		if typeof(stored_volume) in [TYPE_FLOAT, TYPE_INT]:
			volume = clampf(float(stored_volume), 0.0, 1.0)
		var stored_fullscreen = saved.get_value("display", "fullscreen", false)
		if typeof(stored_fullscreen) == TYPE_BOOL: fullscreen = stored_fullscreen
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	if DisplayServer.get_name() != "headless":
		var current_mode := DisplayServer.window_get_mode()
		if fullscreen and current_mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and current_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> Error:
	var saved := ConfigFile.new()
	saved.set_value("audio", "volume", volume)
	saved.set_value("display", "fullscreen", fullscreen)
	return saved.save(preference_path)
