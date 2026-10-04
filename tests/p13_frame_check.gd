extends SceneTree

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/manifest-v03.json"))
	var rows: Array = []
	var passed := true
	for actor in manifest.actors:
		var picture := Image.load_from_file(ProjectSettings.globalize_path(actor.texture))
		var heights: Array[float] = []
		for name in ["idle","walk_a","walk_b"]:
			var frame: Array = actor.frames[name]
			var anchor: Array = actor.anchor[name]
			var minimum := Vector2i(frame[2],frame[3])
			var maximum := Vector2i(-1,-1)
			for y in range(frame[3]):
				for x in range(frame[2]):
					if roundi(picture.get_pixel(frame[0]+x,frame[1]+y).a*255) > 32:
						minimum = minimum.min(Vector2i(x,y))
						maximum = maximum.max(Vector2i(x,y))
			var ratio: float = actor.world_height/float(frame[3])
			var foot_error: float = (maximum.y+1-anchor[1])*ratio
			var height: float = (maximum.y-minimum.y+1)*ratio
			var valid: bool = maximum.x >= 0 and absf(foot_error) < 0.05 and minimum.x > 0 and minimum.y > 0 and maximum.x < frame[2]-1 and maximum.y < frame[3]-1
			heights.append(height)
			passed = passed and valid
			rows.append({"actor":actor.actor_id,"frame":name,"alpha_bounds":[minimum.x,minimum.y,maximum.x-minimum.x+1,maximum.y-minimum.y+1],"foot_error":foot_error,"visible_world_height":height,"passed":valid})
		passed = passed and heights.max()-heights.min() < 0.05
	var report := {"passed":passed,"rows":rows,"scope":"independent native original-PNG alpha >32 measurement; foot registered and visible height stable, no pixel modification","comparison_note":"Initial inclusive >=32 threshold included two fringe pixels; corrected to the documented >32 registration threshold. Initial evidence retained separately."}
	var file := FileAccess.open("res://docs/tests/p13-frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P13_FRAMES passed=",passed," rows=",rows.size())
	quit(0 if passed else 1)
