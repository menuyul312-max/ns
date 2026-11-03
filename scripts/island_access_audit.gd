class_name IslandAccessAudit
extends RefCounted
## Independent Nusantara walkability experiment, not a recovered ACNH algorithm.
## Cardinal dry-tile movement plus explicitly authored ramp/bridge edges.
## Diagonal movement, jumping and swimming are future graph types.

const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]


static func analyze(island: IslandDefinition) -> Dictionary:
	var labels := PackedInt32Array()
	labels.resize(island.width * island.depth)
	labels.fill(-1)  # Non-walkable water remains -1.
	var regions: Array[Dictionary] = []
	var dry_count: int = 0
	var bridge_count: int = 0
	for z in range(island.depth):
		for x in range(island.width):
			if not IslandLinkRules.is_walk_node(island, Vector2i(x, z)):
				continue
			if island.is_water(x, z):
				bridge_count += 1
			else:
				dry_count += 1
			var seed_index: int = z * island.width + x
			if labels[seed_index] >= 0:
				continue
			var region_id: int = regions.size()
			var tile_level: int = island.height_at(x, z)
			var queue: Array[Vector2i] = [Vector2i(x, z)]
			var head: int = 0
			labels[seed_index] = region_id
			while head < queue.size():
				var tile: Vector2i = queue[head]
				head += 1
				for direction in CARDINALS:
					var neighbor: Vector2i = tile + direction
					if not IslandLinkRules.walk_edge(island, tile, neighbor):
						continue
					var index: int = neighbor.y * island.width + neighbor.x
					if labels[index] >= 0:
						continue
					labels[index] = region_id
					queue.append(neighbor)
			regions.append({"id": region_id, "size": queue.size(), "level": tile_level, "seed": Vector2i(x, z)})
	var largest: int = 0
	for region in regions:
		largest = maxi(largest, int(region["size"]))
	return {"labels": labels, "regions": regions, "count": regions.size(), "dry_tiles": dry_count, "bridge_tiles": bridge_count, "largest": largest}


static func preview_change(island: IslandDefinition, x: int, z: int, next_height: int, next_water: bool, next_connector: int = -1, link_cells: Array[Vector2i] = []) -> Dictionary:
	if not island.contains(x, z):
		return {"allowed": false, "code": "OUTSIDE_MAP", "message": "Di luar batas pulau"}
	var before: Dictionary = analyze(island)
	var candidate := IslandDefinition.from_dictionary(island.as_dictionary())
	candidate.set_height(x, z, next_height)
	candidate.set_water(x, z, next_water)
	if next_connector >= 0:
		if link_cells.is_empty():
			candidate.set_connector(x, z, next_connector)
		else:
			for cell in link_cells:
				candidate.set_connector(cell.x, cell.y, next_connector)
	var after: Dictionary = analyze(candidate)
	var split_regions: Dictionary = {}
	var old_labels: PackedInt32Array = before["labels"]
	var new_labels: PackedInt32Array = after["labels"]
	for index in range(old_labels.size()):
		# Ignore edited tile and any water/dry transitions. Only unchanged
		# dry tile pairs are protected against losing mutual reachability.
		if index == z * island.width + x or old_labels[index] < 0 or new_labels[index] < 0:
			continue
		var original_id: int = old_labels[index]
		if not split_regions.has(original_id):
			split_regions[original_id] = {}
		(split_regions[original_id] as Dictionary)[new_labels[index]] = true
	for original_id in split_regions:
		var successors: Dictionary = split_regions[original_id]
		if successors.size() > 1:
			return {
				"allowed": false,
				"code": "ACCESS_SPLIT",
				"message": "Edit memutus jalur antar tile yang sebelumnya terhubung",
				"before_regions": before["count"], "after_regions": after["count"],
				"source": "nusantara_experimental_connectivity"
			}
	return {"allowed": true, "code": "ACCESS_OK", "message": "Jalur yang ada tetap terhubung", "before_regions": before["count"], "after_regions": after["count"], "source": "nusantara_experimental_connectivity"}


static func preview_mask_change(island: IslandDefinition, x: int, z: int, enabled: bool) -> Dictionary:
	if not island.contains(x, z):
		return {"allowed": false, "code": "OUTSIDE_MAP", "message": "Di luar denah"}
	var before: Dictionary = analyze(island)
	var candidate := IslandDefinition.from_dictionary(island.as_dictionary())
	candidate.set_land(x, z, enabled)
	var after: Dictionary = analyze(candidate)
	var old_labels: PackedInt32Array = before["labels"]
	var new_labels: PackedInt32Array = after["labels"]
	var preserved: Dictionary = {}
	for index in range(old_labels.size()):
		if index == z * island.width + x or old_labels[index] < 0 or new_labels[index] < 0:
			continue
		var original_id: int = old_labels[index]
		if not preserved.has(original_id):
			preserved[original_id] = {}
		(preserved[original_id] as Dictionary)[new_labels[index]] = true
	for original_id in preserved:
		if (preserved[original_id] as Dictionary).size() > 1:
			return {"allowed": false, "code": "MASK_ACCESS_SPLIT", "message": "Penghapusan darat akan memutus jalur berjalan"}
	return {"allowed": true, "code": "ACCESS_OK", "message": "Kontinuitas jalur tetap terjaga"}
