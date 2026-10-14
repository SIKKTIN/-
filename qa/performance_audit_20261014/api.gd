extends SceneTree
func _initialize():
 for m in ClassDB.class_get_method_list("RenderingServer"):
  if str(m.name) in ["texture_debug_usage","viewport_set_measure_render_time","viewport_get_measured_render_time_cpu","viewport_get_measured_render_time_gpu"]:print(JSON.stringify(m))
 quit()
