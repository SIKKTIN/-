extends SceneTree
func _initialize():call_deferred("bootstrap")
func bootstrap():
 print("BASELINE_BOOT")
 if not ProjectSettings.load_resource_pack("res://docs/performance/resource-optimization-20261014/baseline-overlay.pck",true):quit(2);return
 print("BASELINE_MOUNTED")
 var test_path: String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://qa/p131_scene_seams.gd"
 var test=load(test_path)
 set_script(test)
 call_deferred("run")
