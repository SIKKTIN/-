@tool
extends RefCounted

# Capture visual hit shapes once per stroke. Array indexes change before the
# deferred preview refresh, so remap these shapes after each removal batch.
var candidates: Array[Dictionary] = []

func capture(canvas) -> void:
	candidates.clear()
	if canvas.architecture_preview.pending: canvas.architecture_preview.refresh()
	var entries: Array = canvas.document.eraser_entries()
	entries.reverse()
	for pass_index in range(3):
		for ref in entries:
			if not canvas.document.can_remove(ref) or not canvas.layers.is_editable(ref.group): continue
			if canvas.document.removal_refs([ref]).any(func(part): return not canvas.layers.is_editable(part.group)): continue
			var layer_pass := 2 if canvas.layers.key_for(ref.group) == "ground" else 1 if ref.group in ["zones","visibility_rooms"] else 0
			if layer_pass != pass_index: continue
			var rect: Rect2 = canvas.document.geometry(ref)
			var areas: Array[Rect2] = []
			if ref.group == "fixtures" and not canvas.show_collision:
				if canvas.document.value(ref).get("hidden",false) or canvas.beneath_roof(rect.get_center()): continue
			if canvas.document.is_rect(ref):
				if not canvas.show_collision and ref.group in ["walls","fixtures","access_doors","dorm_doors"]:
					areas.assign(canvas.architecture_preview.visual_hit_areas(ref))
				else: areas.append(rect.grow(5/canvas.zoom))
			else: areas.append(Rect2(rect.position-Vector2.ONE*11/canvas.zoom,Vector2.ONE*22/canvas.zoom))
			if not areas.is_empty(): candidates.append({"ref":ref.duplicate(),"areas":areas,"point":not canvas.document.is_rect(ref),"center":rect.position})

func sweep(canvas, start: Vector2, end: Vector2) -> Array:
	var refs: Array = []
	var seen := {}
	var steps := maxi(1,ceili(start.distance_to(end)/6))
	var sweep_area := Rect2(start,Vector2.ZERO).expand(end).grow(12)
	var nearby: Array[Dictionary] = []
	for candidate in candidates:
		for area in candidate.areas:
			if Rect2(canvas.screen(area.position),area.size*canvas.zoom).intersects(sweep_area):
				nearby.append(candidate)
				break
	for step in range(steps+1):
		var pointer := start.lerp(end,float(step)/steps)
		if not Rect2(Vector2.ZERO,canvas.size).has_point(pointer): continue
		var point: Vector2 = canvas.world(pointer)
		for candidate in nearby:
			var hit: bool = point.distance_to(candidate.center) <= 11/canvas.zoom if candidate.point else candidate.areas.any(func(area):return area.has_point(point))
			if hit and candidate.ref.group == "ground_details": hit = preload("res://scripts/presentation/site_details.gd").hit_test(canvas.document.value(candidate.ref),point,5/canvas.zoom)
			if not hit: continue
			var ref: Dictionary = candidate.ref
			var key := "%s:%d" % [ref.group,int(ref.index)]
			if not seen.has(key):
				seen[key] = true
				refs.append(ref.duplicate())
			break
	return refs

func remap(removed: Array) -> void:
	var survivors: Array[Dictionary] = []
	for candidate in candidates:
		if candidate.ref in removed: continue
		var index := int(candidate.ref.index)
		var shift := 0
		for ref in removed:
			if ref.group == candidate.ref.group and int(ref.index) < index: shift += 1
		candidate.ref.index = index-shift
		survivors.append(candidate)
	candidates = survivors
