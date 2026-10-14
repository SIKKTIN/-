extends SceneTree

const Store=preload("res://scripts/presentation/runtime_texture_store.gd")
const Textures=preload("res://scripts/presentation/world_texture.gd")
const OUT="res://docs/performance/resource-optimization-20261014/"
var checks: Dictionary={}
func _initialize():call_deferred("run")
func check(label: String, ok: bool):
	checks[label]=ok
	if not ok:push_error("Resource regression: "+label)
func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://resource-texture-qa.cfg")
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Store.INDEX))
	check("complete desktop bake",int(index.schema)==2)
	var wrong_size: Array=[]
	var missing: Array=[]
	var changed_source: Array=[]
	var unsafe_compression: Array=[]
	var compressed:=0
	var aliases: Dictionary={}
	for key in index.textures:
		var entry: Dictionary=index.textures[key]
		var path: String=str(key).get_slice("[",0)
		var asset: Dictionary={"texture":path}
		var bracket: int=str(key).find("[")
		var end: int=str(key).find("]",bracket)
		var region: Array=JSON.parse_string(str(key).substr(bracket,end-bracket+1))
		if not region.is_empty():asset.region=region
		if str(key).contains("::limit"):asset.runtime_size_limit=int(str(key).get_slice("::limit",1))
		var texture:=Store.texture(asset,bool(entry.base))
		if texture==null:missing.append(key);continue
		if texture.get_size()!=Vector2(entry.size[0],entry.size[1]):wrong_size.append(key)
		if not aliases.has(entry.resource):aliases[entry.resource]=texture
		elif aliases[entry.resource]!=texture:wrong_size.append(key+": duplicate alias")
		if FileAccess.get_sha256(path)!=str(entry.source_sha256):changed_source.append(path)
		if bool(entry.get("vram_compressed",false)):
			compressed+=1
			if path.begins_with("res://art/characters/") or path.begins_with("res://art/ui/") or path.begins_with("res://art/items/") or entry.base:unsafe_compression.append(key)
	check("all generated resources load",missing.is_empty())
	check("block alignment preserves logical dimensions and aliases",wrong_size.is_empty())
	check("source art matches bake hashes",changed_source.is_empty())
	check("world textures compressed",compressed>300)
	check("characters UI items and base frames remain lossless",unsafe_compression.is_empty())
	aliases.clear()
	var sample_key: String=index.textures.keys()[0]
	var saved_entry: Dictionary=Store.entries[sample_key].duplicate(true)
	Store.entries[sample_key].source_modified=-1
	var sample_asset: Dictionary={"texture":sample_key.get_slice("[",0)}
	var region_start:=sample_key.find("[")
	var region_end:=sample_key.find("]")
	sample_asset.region=JSON.parse_string(sample_key.substr(region_start,region_end-region_start+1))
	if sample_key.contains("::limit"):sample_asset.runtime_size_limit=int(sample_key.get_slice("::limit",1))
	check("changed source bypasses stale bake",Store.texture(sample_asset,bool(saved_entry.base))==null)
	Store.entries[sample_key]=saved_entry
	Store.hits=0;Store.misses=0
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.fullscreen_ui.set_process(false)
	var lamps: Array=game.presentation.lighting.lamps
	var lamp_rids: Dictionary={}
	var dimensions: Dictionary={}
	for lamp in lamps:
		lamp_rids[lamp.texture.get_rid()]=true
		dimensions[lamp.texture.get_size()]=true
	check("identical lamp gradients share one texture",lamp_rids.size()==dimensions.size() and lamp_rids.size()<lamps.size())
	var reload_counts: Array=[]
	for room in ["r01","r02","r03","r04","r04"]:
		check("load "+room+str(reload_counts.size()),game.load_room(room,["chat","chat","backpack"],136))
		await process_frame;await process_frame
		check("exit icon "+room,game.world.art_textures.has("exit_v01"))
		reload_counts.append(Textures.cache.size())
	check("all maps avoid source fallback",Store.misses==0)
	check("reload releases old cache ownership",reload_counts[3]==reload_counts[4])
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var report: Dictionary={"checks":checks,"failed":failed,"missing":missing,"wrong_size":wrong_size,"source_changes":changed_source,"compressed":compressed,"baked_hits":Store.hits,"baked_misses":Store.misses,"reload_counts":reload_counts,"lamp_count":lamps.size(),"unique_lamp_textures":lamp_rids.size()}
	FileAccess.open(OUT+"regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.queue_free();await process_frame;quit(0 if failed.is_empty() else 1)
