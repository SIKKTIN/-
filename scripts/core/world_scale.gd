@tool
extends RefCounted

# Character proportions. Atlas pixels, foot anchors and HUD portraits keep
# their original registration; only their size in the game world changes.
const HUMAN := 1.5
const DOG := 1.6

static func human_height(asset: Dictionary) -> float:
	return float(asset.get("world_height",60))*HUMAN
