extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary={}
var profile_total_ms:=0.0
var profile_frame
func _make_world():
 return load("res://qa/smoothness_optimization_20261014/world_"+OS.get_environment("SMOOTH_TEST_VARIANT")+".gd").new()
func _process(delta: float):
 profile_sections.clear()
 world.pathfinding.audit_records.clear()
 var mark:=Time.get_ticks_usec()
 profile_frame.tick(self,delta)
 profile_total_ms=(Time.get_ticks_usec()-mark)/1000.0

func _ready():
 var catalog=preload("res://scripts/presentation/prop_catalog.gd")
 catalog.cached_assets=JSON.parse_string(FileAccess.get_file_as_string("res://docs/dev/smoothness-optimization-2026-10-14/catalog-benchmark.json"))
 catalog.next_catalog_check=Time.get_ticks_msec()+600000
 profile_frame=load("res://qa/smoothness_optimization_20261014/frame_"+OS.get_environment("SMOOTH_TEST_VARIANT")+".gd")
 preload("res://qa/smoothness_optimization_20261014/bootstrap.gd").configure(self)
 set_process(false)
