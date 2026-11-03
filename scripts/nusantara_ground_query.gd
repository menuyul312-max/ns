class_name NusantaraGroundQuery
extends RefCounted
## Native-inspired four-direction *sampling topology*, with OUR ORIGINAL
## terrain data and thresholds. This is an adaptation, NOT proof that ACNH
## uses these values for water, shore collision, or edit permission.


static func sample_tile(island: IslandDefinition, x: int, z: int) -> Dictionary:
	var water_flags := PackedByteArray()
	var no_entry_flags := PackedByteArray()
	var positions: Array[Vector2] = []
	var relative: Array[Vector2] = [Vector2(0.5, 0.25), Vector2(0.25, 0.5), Vector2(0.5, 0.75), Vector2(0.75, 0.5)]
	for uv in relative:
		var point := Vector2((float(x) + uv.x) * IslandDefinition.TILE_SIZE, (float(z) + uv.y) * IslandDefinition.TILE_SIZE)
		positions.append(point)
		var land: bool = CoastContour.on_island(island, point.x, point.y)
		var wet: bool = land and RiverContour.field_at(island, point.x, point.y, island.height_at(x, z)) >= RiverContour.THRESHOLD
		water_flags.append(1 if wet else 0)
		no_entry_flags.append(0 if land else 1)
	return {
		"points": positions,
		"water_flags": water_flags,
		"no_entry_flags": no_entry_flags,
		"all_water": NativeTerrainReference.all_four_match(water_flags),
		"any_no_entry": NativeTerrainReference.any_four_match(no_entry_flags),
		"two_water": NativeTerrainReference.exactly_two_match(water_flags)
	}
