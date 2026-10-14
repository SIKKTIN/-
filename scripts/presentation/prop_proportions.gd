@tool
extends RefCounted

const CONFIG := "res://data/presentation/prop_proportions.json"
static var settings: Dictionary = {}

static func apply(assets: Dictionary) -> void:
	if settings.is_empty():settings=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	# The reference records the furniture calibration, not the live actor size.
	# Character scale trials must not silently resize the whole environment.
	var human_height: float=float(settings.reference_human_height)
	for id in settings.widths_at_reference:
		if not assets.has(id):continue
		var asset: Dictionary=assets[id]
		if str(asset.get("render_mode",""))!="projected_prop" or not asset.has("ground_rect"):continue
		var source: Vector2=source_size(asset)
		var scale: float=float(settings.widths_at_reference[id])/source.x
		var ground: Array=asset.ground_rect
		var dimensions: Vector2=source*scale
		asset.world_size=[dimensions.x,dimensions.y]
		asset.render_size=asset.world_size.duplicate()
		asset.footprint_world_size=[float(ground[2])*scale,float(ground[3])*scale]
		asset.elevation_world=maxf(0,dimensions.y-float(ground[3])*scale)
		asset.proportion_locked=true
		asset.proportion_reference_human_height=human_height

static func source_size(asset: Dictionary) -> Vector2:
	var region: Array=asset.get("region",[])
	return Vector2(region[2],region[3]) if region.size()==4 else Vector2(asset.texture_size[0],asset.texture_size[1])

static func display_rect(asset: Dictionary, footprint: Rect2) -> Rect2:
	var source: Vector2=source_size(asset)
	var scale: float=float(asset.world_size[0])/source.x
	var ground: Array=asset.ground_rect
	var anchor:=Vector2(float(ground[0])+float(ground[2])*0.5,float(ground[1])+float(ground[3]))
	var feet:=Vector2(footprint.get_center().x,footprint.end.y)
	return Rect2(feet-anchor*scale,source*scale)
