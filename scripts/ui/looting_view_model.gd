extends RefCounted

# Cache structural item data separately from search progress and UI controls.
var source_key: Array=[]
var bag_key: Array=[]
var source_entries: Array=[]
var bag_entries: Array=[]
var source_builds:=0
var bag_builds:=0

func source_items(looting) -> Array:
	var key: Array=[looting.current_id,looting.revision]
	if source_key==key:return source_entries
	source_key=key
	source_builds+=1
	source_entries=[]
	var state: Dictionary=looting.containers[looting.current_id]
	for id in state.ids:
		source_entries.append({"id":id,"rect":state.layout[id],"kind":looting.game.inventory.instances[id].definition_id,"known":state.revealed.get(id,false)})
	return source_entries

func bag_items(inventory) -> Array:
	var ids: Array=inventory.items(0)
	var arrangement: Dictionary=inventory.grid_layout(0)
	var key: Array=[inventory.grid_size(0),ids,inventory.layout_revision]
	if bag_key==key:return bag_entries
	bag_key=key
	bag_builds+=1
	bag_entries=[]
	for id in ids:
		bag_entries.append({"id":id,"rect":arrangement[id],"kind":inventory.instances[id].definition_id})
	return bag_entries
