class_name IslandDefinition
extends RefCounted
## One logical grid owns state. Research-informed two-layer tile metadata,
## implemented independently of Nintendo game resources or model IDs.
## World-space TILE_SIZE/HEIGHT_STEP remain our illustrative parameters.

const TILE_SIZE: float = 2.1
const HEIGHT_STEP: float = 1.55
const VISUAL_VARIATION_LIMITS: Array[int] = [0, 3, 2, 1]

var width: int
var depth: int
var levels: PackedInt32Array
var water: PackedByteArray
var occupants: PackedByteArray
var connectors: PackedByteArray
## Sprint 26: a real presence bit per logical cell. Missing cells are ocean,
## not merely low terrain hidden by a shoreline displacement.
var land_mask: PackedByteArray
var surface_units: PackedByteArray
var surface_variations: PackedByteArray
var surface_rotations: PackedByteArray
var detail_units: PackedByteArray
var detail_variations: PackedByteArray
var detail_rotations: PackedByteArray
## Four independently authored, smoothly interpolated coast profiles.
## 0 west, 1 east (depth+1 samples); 2 north, 3 south (width+1).
## A value is an inward shore displacement in world units. Endpoints are
## pinned to zero to preserve watertight corner joins.
var shore_profiles: Array[PackedFloat32Array] = []
var seed: int = 7219
## Revised whenever shoreline silhouette/river suppression may change.
## This is a lightweight invalidation contract for the shore-distance cache.
var coastline_revision: int = 0


func _init(map_width: int = 1, map_depth: int = 1) -> void:
	assert(map_width > 0 and map_depth > 0)
	width = map_width
	depth = map_depth
	levels.resize(width * depth)
	levels.fill(0)
	water.resize(width * depth)
	water.fill(0)
	occupants.resize(width * depth)
	occupants.fill(0)
	connectors.resize(width * depth)
	connectors.fill(0)
	land_mask.resize(width * depth)
	land_mask.fill(1)
	for field in ["surface_units", "surface_variations", "surface_rotations", "detail_units", "detail_variations", "detail_rotations"]:
		var values := PackedByteArray()
		values.resize(width * depth)
		values.fill(0)
		set(field, values)
	for side in range(4):
		var shore := PackedFloat32Array()
		shore.resize(depth + 1 if side < 2 else width + 1)
		shore.fill(0.0)
		shore_profiles.append(shore)


func coast_inset_at(side: int, along_world: float) -> float:
	assert(side >= 0 and side < 4)
	var profile: PackedFloat32Array = shore_profiles[side]
	var along: float = clampf(along_world / TILE_SIZE, 0.0, float(profile.size() - 1))
	var index: int = mini(floori(along), profile.size() - 2)
	var t: float = smoothstep(0.0, 1.0, along - float(index))
	return lerpf(profile[index], profile[index + 1], t)


func set_coast_inset(side: int, index: int, inward_units: float) -> bool:
	if side < 0 or side > 3 or index <= 0 or index >= shore_profiles[side].size() - 1:
		return false
	shore_profiles[side][index] = clampf(inward_units, 0.0, 1.10)
	coastline_revision += 1
	return true


func contains(x: int, z: int) -> bool:
	return x >= 0 and x < width and z >= 0 and z < depth


func is_land(x: int, z: int) -> bool:
	return contains(x, z) and land_mask[z * width + x] != 0


func set_land(x: int, z: int, enabled: bool) -> void:
	assert(contains(x, z))
	var index: int = z * width + x
	land_mask[index] = 1 if enabled else 0
	coastline_revision += 1
	if not enabled:
		levels[index] = 0
		water[index] = 0
		occupants[index] = 0
		connectors[index] = 0
		for field in ["surface_units", "surface_variations", "surface_rotations", "detail_units", "detail_variations", "detail_rotations"]:
			var values: PackedByteArray = get(field)
			values[index] = 0
			set(field, values)


func height_at(x: int, z: int) -> int:
	if not is_land(x, z):
		return 0
	return levels[z * width + x]


func set_height(x: int, z: int, height_level: int) -> void:
	assert(is_land(x, z))
	assert(height_level >= 0 and height_level <= 5)
	levels[z * width + x] = height_level
	coastline_revision += 1


func is_water(x: int, z: int) -> bool:
	return is_land(x, z) and water[z * width + x] != 0


func set_water(x: int, z: int, enabled: bool) -> void:
	assert(is_land(x, z))
	water[z * width + x] = 1 if enabled else 0
	coastline_revision += 1


func occupant_at(x: int, z: int) -> int:
	return int(occupants[z * width + x]) if is_land(x, z) else 0


func set_occupant(x: int, z: int, kind: int) -> void:
	# 0 empty; 1 tree; 2 small Nusantara structure; names and models original.
	assert(is_land(x, z) and kind >= 0 and kind <= 2)
	occupants[z * width + x] = kind


func connector_at(x: int, z: int) -> int:
	return int(connectors[z * width + x]) if is_land(x, z) else 0


func set_connector(x: int, z: int, kind: int) -> void:
	# Nusantara enum: 0 none, 1..4 ramp to N/E/S/W, 5 EW bridge, 6 NS bridge.
	assert(is_land(x, z) and kind >= 0 and kind <= 6)
	connectors[z * width + x] = kind


func terrain_layer_at(x: int, z: int, layer: int) -> Dictionary:
	if not is_land(x, z) or layer < 0 or layer > 1:
		return {"unit": 0, "variation": 0, "rotation": 0}
	var index: int = z * width + x
	if layer == 0:
		return {"unit": surface_units[index], "variation": surface_variations[index], "rotation": surface_rotations[index]}
	return {"unit": detail_units[index], "variation": detail_variations[index], "rotation": detail_rotations[index]}


func set_terrain_layer(x: int, z: int, layer: int, unit: int, variation: int, rotation: int) -> void:
	assert(is_land(x, z) and layer >= 0 and layer <= 1)
	# IDs 0..3 are original Nusantara palette entries, NOT ACNH model IDs.
	assert(unit >= 0 and unit <= 3 and variation >= 0 and variation <= 3 and rotation >= 0 and rotation <= 3)
	var index: int = z * width + x
	if layer == 0:
		surface_units[index] = unit
		surface_variations[index] = variation
		surface_rotations[index] = rotation
	else:
		detail_units[index] = unit
		detail_variations[index] = variation
		detail_rotations[index] = rotation


func terrain_record_at(x: int, z: int) -> Array[int]:
	var base: Dictionary = terrain_layer_at(x, z, 0)
	var detail: Dictionary = terrain_layer_at(x, z, 1)
	return [int(base["unit"]), int(base["variation"]), int(base["rotation"]), int(detail["unit"]), int(detail["variation"]), int(detail["rotation"]), height_at(x, z)]


static func normalize_reference_height(raw_height: int) -> int:
	# RE ACNH 1.0.0 getter: 0..5 accepted; >=6 maps to 4, NOT clamp(,4).
	# This utility is for validating external study records, not live editing.
	return raw_height if raw_height >= 0 and raw_height <= 5 else 4


static func effective_visual_variation(unit: int, variant: int) -> int:
	if unit < 0 or unit >= VISUAL_VARIATION_LIMITS.size():
		return 0
	return variant if variant >= 0 and variant <= VISUAL_VARIATION_LIMITS[unit] else 0


func waterfall_edge_count() -> int:
	var count: int = 0
	for z in range(depth):
		for x in range(width):
			if not is_water(x, z):
				continue
			var level: int = height_at(x, z)
			for neighbor in [Vector2i(x, z - 1), Vector2i(x + 1, z), Vector2i(x, z + 1), Vector2i(x - 1, z)]:
				if is_water(neighbor.x, neighbor.y) and height_at(neighbor.x, neighbor.y) < level:
					count += 1
	return count


func cliff_edge_count() -> int:
	var count: int = 0
	for z in range(depth):
		for x in range(width):
			if not is_land(x, z):
				continue
			var elevation: int = height_at(x, z)
			if elevation > height_at(x, z - 1):
				count += 1
			if elevation > height_at(x + 1, z):
				count += 1
			if elevation > height_at(x, z + 1):
				count += 1
			if elevation > height_at(x - 1, z):
				count += 1
	return count


func as_dictionary() -> Dictionary:
	return {
		"schema_version": 7,
		"width": width,
		"depth": depth,
		"seed": seed,
		"levels": Array(levels),
		"water": Array(water),
		"occupants": Array(occupants),
		"connectors": Array(connectors),
		"land_mask": Array(land_mask),
		"shore_profiles": [Array(shore_profiles[0]), Array(shore_profiles[1]), Array(shore_profiles[2]), Array(shore_profiles[3])],
		"terrain_layers": [
			{"unit": Array(surface_units), "variation": Array(surface_variations), "rotation": Array(surface_rotations)},
			{"unit": Array(detail_units), "variation": Array(detail_variations), "rotation": Array(detail_rotations)}
		]
	}


static func from_dictionary(input: Dictionary) -> IslandDefinition:
	assert(int(input.get("schema_version", 0)) in [1, 2, 3, 4, 5, 6, 7])
	var result := IslandDefinition.new(int(input["width"]), int(input["depth"]))
	result.seed = int(input.get("seed", 0))
	var values: Array = input["levels"]
	assert(values.size() == result.width * result.depth)
	for index in range(values.size()):
		var level: int = int(values[index])
		assert(level >= 0 and level <= 5)
		result.levels[index] = level
	if int(input.get("schema_version", 1)) >= 2:
		var water_values: Array = input["water"]
		assert(water_values.size() == result.width * result.depth)
		for index in range(water_values.size()):
			result.water[index] = 1 if int(water_values[index]) != 0 else 0
	if int(input.get("schema_version", 1)) >= 3:
		var layers: Array = input["terrain_layers"]
		for layer_index in range(2):
			var layer_data: Dictionary = layers[layer_index]
			for index in range(result.width * result.depth):
				var x: int = index % result.width
				var z: int = floori(float(index) / float(result.width))
				result.set_terrain_layer(x, z, layer_index, int(layer_data["unit"][index]), int(layer_data["variation"][index]), int(layer_data["rotation"][index]))
	if int(input.get("schema_version", 1)) >= 4:
		var values_occupants: Array = input["occupants"]
		for index in range(result.width * result.depth):
			result.occupants[index] = int(values_occupants[index])
	if int(input.get("schema_version", 1)) >= 5:
		var link_values: Array = input["connectors"]
		for index in range(result.width * result.depth):
			result.connectors[index] = int(link_values[index])
	if int(input.get("schema_version", 1)) >= 6:
		var profiles: Array = input["shore_profiles"]
		assert(profiles.size() == 4)
		for side in range(4):
			assert(profiles[side].size() == result.shore_profiles[side].size())
			for index in range(1, result.shore_profiles[side].size() - 1):
				result.set_coast_inset(side, index, float(profiles[side][index]))
	if int(input.get("schema_version", 1)) >= 7:
		var cells: Array = input["land_mask"]
		assert(cells.size() == result.width * result.depth)
		for index in range(cells.size()):
			if int(cells[index]) == 0:
				result.set_land(index % result.width, floori(float(index) / float(result.width)), false)
	return result


static func fixture_terraces() -> IslandDefinition:
	var result := IslandDefinition.new(10, 8)
	var rows: Array[PackedInt32Array] = [
		PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
		PackedInt32Array([0, 1, 1, 1, 1, 1, 1, 0, 0, 0]),
		PackedInt32Array([0, 1, 2, 2, 2, 1, 1, 1, 0, 0]),
		PackedInt32Array([0, 1, 2, 2, 2, 2, 1, 1, 0, 0]),
		PackedInt32Array([0, 1, 2, 2, 2, 1, 1, 1, 0, 0]),
		PackedInt32Array([0, 1, 1, 1, 1, 1, 1, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
		PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	]
	for z in range(rows.size()):
		for x in range(rows[z].size()):
			result.set_height(x, z, rows[z][x])
	return result


static func fixture_bend() -> IslandDefinition:
	var result := IslandDefinition.new(8, 8)
	for z in range(1, 7):
		for x in range(1, 7):
			if x < 5 or z < 4:
				result.set_height(x, z, 1)
	for z in range(2, 5):
		for x in range(2, 5):
			if z <= 3 or x <= 3:
				result.set_height(x, z, 2)
	return result


static func fixture_river() -> IslandDefinition:
	# Hand-authored river concept: spring on a terrace, one fall, meander to coast.
	var result := IslandDefinition.new(14, 10)
	for z in range(1, 7):
		for x in range(1, 9):
			result.set_height(x, z, 1)
	for z in range(3, 6):
		for x in range(2, 5):
			result.set_height(x, z, 2)
	var route: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(6, 2), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
		Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 3), Vector2i(10, 4),
		Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6),
		Vector2i(10, 5), Vector2i(10, 6), Vector2i(10, 7),
		Vector2i(9, 7), Vector2i(9, 8), Vector2i(10, 8)
	]
	for cell in route:
		result.set_water(cell.x, cell.y, true)
	# Original Nusantara footpath and decorative motifs showcase independent
	# surface/detail layers; these are not extracted ACNH layout or item IDs.
	for cell in [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(7, 4), Vector2i(8, 4)]:
		result.set_terrain_layer(cell.x, cell.y, 0, 1, (cell.x + cell.y) % 4, (cell.x + 2 * cell.y) % 4)
	result.set_terrain_layer(5, 5, 1, 1, 2, 0)
	result.set_terrain_layer(7, 5, 1, 2, 1, 2)
	result.set_terrain_layer(8, 4, 1, 3, 3, 1)
	return result


static func fixture_coast_mask() -> IslandDefinition:
	# Sprint 26 hand-authored topology: asymmetric island, eastern bay, southern
	# inlet, and detached sandbar. No Nintendo map or placement data is used.
	var result := IslandDefinition.new(20, 14)
	for z in range(result.depth):
		for x in range(result.width):
			var nx: float = (float(x) - 9.4) / 9.3
			var nz: float = (float(z) - 6.4) / 6.6
			var natural_radius: float = nx * nx + nz * nz
			var edge_wave: float = 0.085 * sin(float(x) * 0.72) + 0.067 * sin(float(z) * 0.83)
			var missing: bool = natural_radius + edge_wave > 0.93
			# Cove reaching from east, with a stepped / irregular shore.
			if x >= 14 and z >= 4 and z <= 9 and x + int(absf(float(z) - 6.5)) >= 16:
				missing = true
			if x >= 8 and x <= 9 and z >= 11:
				missing = true
			# The original demonstration islet accidentally shared a one-tile
			# land bridge at (16, 10). Reserve a narrow sea channel so its
			# independent topology matches the fixture's intended description.
			if x == 16 and z >= 9:
				missing = true
			if missing:
				result.set_land(x, z, false)
	# Restore a small outlying islet near the lower-right coast.
	for z in range(10, 13):
		for x in range(17, 20):
			if (x - 18) * (x - 18) + (z - 11) * (z - 11) <= 2:
				result.set_land(x, z, true)
	# One high source plateau with a falling river toward the south inlet.
	for z in range(2, 6):
		for x in range(4, 10):
			if result.is_land(x, z):
				result.set_height(x, z, 1)
	var river_center_by_row: Array[int] = [6, 6, 7, 7, 8, 8, 9, 8, 8]
	for row in range(river_center_by_row.size()):
		var z: int = row + 2
		for x in [river_center_by_row[row], river_center_by_row[row] + 1]:
			if result.is_land(x, z):
				result.set_water(x, z, true)
	for item in [Vector2i(4, 7), Vector2i(11, 4), Vector2i(13, 10)]:
		if result.is_land(item.x, item.y) and not result.is_water(item.x, item.y):
			result.set_occupant(item.x, item.y, 1)
	if result.is_land(12, 8) and not result.is_water(12, 8):
		result.set_occupant(12, 8, 2)
	return result
