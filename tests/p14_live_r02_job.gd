extends "res://tests/p13_live_r02_job.gd"

func _finish(passed: bool, reason: String) -> void:
	game.orders.clear()
	state = "finished"
	result = {"passed":passed,"reason":reason,"route":route,"trace":trace,"snapshot":game.snapshot(),"presentation":game.presentation.snapshot()}
	var file := FileAccess.open("res://docs/tests/p14-live-r02.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	get_viewport().get_texture().get_image().save_png("res://docs/tests/p14-live-r02.png")
	set_process(false)
