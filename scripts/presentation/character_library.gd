@tool
extends RefCounted

const CATALOG := "res://data/presentation/character_libraries.json"
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
static var entries: Dictionary = {}
static var prepared_motions: Dictionary = {}

static func all() -> Dictionary:
	if entries.is_empty():
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		for path in catalog.get("libraries",[]):
			if not FileAccess.file_exists(path):continue
			var manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
			if manifest is Dictionary:
				for asset in manifest.get("characters",[]):entries[str(asset.id)]=asset
	return entries

# Prepare only appearances that are actually used. Decode each sheet once,
# crop before generating mipmaps, and share these textures between actors.
static func motion(id: String) -> Dictionary:
	if prepared_motions.has(id):return prepared_motions[id]
	var asset: Dictionary=all().get(id,{})
	if asset.is_empty():return {}
	var walk_path: String=str(asset.walk_animation.texture)
	var regions: Array=[]
	for frame in asset.walk_animation.frames:regions.append(frame.region)
	var idle_texture: Texture2D
	var walks: Array[Texture2D]=[]
	if walk_path==str(asset.texture):
		# Decode a combined sheet once, retaining the idle's sharp filtering.
		regions.push_front(asset.frames.idle)
		var textures: Array[Texture2D]=WorldTexture.load_regions(walk_path,regions,[0])
		if textures.any(func(t):return t==null):return {}
		idle_texture=textures[0]
		for i in range(1,textures.size()):walks.append(textures[i])
	else:
		# A revised walk sheet can preserve the approved idle and portrait.
		idle_texture=idle(id)
		walks=WorldTexture.load_regions(walk_path,regions)
	if idle_texture==null or walks.any(func(t):return t==null):return {}
	prepared_motions[id]={"idle":idle_texture,"walk":walks}
	return prepared_motions[id]

static func idle(id: String) -> Texture2D:
	var asset: Dictionary=all().get(id,{})
	if asset.is_empty():return null
	return WorldTexture.load_regions(str(asset.texture),[asset.frames.idle],[0])[0]

static func portrait(id: String) -> Texture2D:
	var asset: Dictionary=all().get(id,{})
	if asset.is_empty():return null
	return WorldTexture.load_asset({"texture":asset.texture,"region":asset.portrait_region})

static func key_for(ref: Dictionary, config: Dictionary) -> String:
	match str(ref.group):
		"starts":return "actor:"+str(int(ref.index))
		"guard_start":return "guard"
		"gate_guards":return "gate:"+str(config.gate_guards[ref.index].id)
		"merchants":return "merchant:"+str(config.merchants[ref.index].id)
	return ""

static func id_for(game, actor) -> String:
	var key: String=""
	var fallback: String=""
	if actor==game.guard:
		key="guard";fallback="patrol_guard"
	elif actor.has_method("is_workshop_overseer"):
		key="overseer";fallback="overseer"
	elif actor.has_method("is_gate_guard"):
		key="gate:"+str(actor.guard_id);fallback="patrol_guard"
	elif actor.has_method("inspection_allowed"):
		key="guard";fallback="patrol_guard"
	elif actor in game.actors:
		key="actor:"+str(actor.actor_id)
		if int(actor.actor_id)>0:
			var pool: Array=["young_worker","stocky_worker","older_worker","female_worker"]
			fallback=pool[posmod(int(game.deal_seed)+int(actor.actor_id)-1,pool.size())]
	elif game.trade:
		for id in game.trade.actors:
			if game.trade.actors[id]==actor:key="merchant:"+str(id);break
	var choices: Dictionary=game.room_config.get("character_appearances",{})
	# Empty explicitly means the existing appearance, including the player.
	var id: String=str(choices.get(key,fallback))
	return id if all().has(id) else ""

static func for_actor(game,actor,base: Dictionary) -> Dictionary:
	var id:=id_for(game,actor)
	if id.is_empty():return base.duplicate(true)
	var result:=base.duplicate(true)
	result.merge(all()[id].duplicate(true),true)
	result.actor_id=base.actor_id
	result.appearance_id=id
	return result
