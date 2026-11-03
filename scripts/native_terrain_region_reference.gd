class_name NativeTerrainRegionReference
extends RefCounted
## Clean-room model of *bounded* region contracts verified in the user's RE.
## All coordinates here are RECORD INDICES, not Godot world coordinates.
## This is deliberately separate from Nusantara build permissions and physics.
## ELF ACNH 1.0.0: 0x181fa0, 0x181ae0, 0x185c80, 0x185e70.

const INHERIT: int = 7
const HEIGHT_SPREAD_LIMIT: float = 0.10999999940395355
const BIT_REGION_2: int = 1 << 2
const BIT_REGION_6: int = 1 << 6

var width: int
var depth: int
var words: PackedInt32Array
var base_heights: PackedFloat32Array
var overlay_heights: PackedFloat32Array
var overlay_first_attributes: PackedByteArray


func _init(map_width: int = 1, map_depth: int = 1) -> void:
	assert(map_width > 0 and map_depth > 0)
	width = map_width
	depth = map_depth
	var size: int = width * depth
	words.resize(size)
	words.fill(0)
	base_heights.resize(size)
	base_heights.fill(0.0)
	overlay_heights.resize(size)
	overlay_heights.fill(0.0)
	overlay_first_attributes.resize(size)
	overlay_first_attributes.fill(INHERIT)


func contains(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < width and z < depth


func set_sample(x: int, z: int, word: int, base_height: float, overlay_height: float = 0.0, overlay_attribute: int = INHERIT) -> void:
	assert(contains(x, z))
	assert(is_finite(base_height) and is_finite(overlay_height))
	assert(overlay_attribute >= 0 and overlay_attribute <= 255)
	var i: int = z * width + x
	words[i] = word
	base_heights[i] = base_height
	overlay_heights[i] = overlay_height
	overlay_first_attributes[i] = overlay_attribute


func mutate_region(start: Vector2i, end: Vector2i, bit_mask: int, mode: int) -> int:
	## Verified mode low bit: 0 clears, 1 sets; mode 2/3 repeat 0/1.
	## Returns *our* count of intersecting cells, not a native return value.
	assert(bit_mask == BIT_REGION_2 or bit_mask == BIT_REGION_6)
	var bounds: Rect2i = _intersection(start, end)
	var affected: int = 0
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var i: int = z * width + x
			if (mode & 1) != 0:
				words[i] |= bit_mask
			else:
				words[i] &= ~bit_mask
			affected += 1
	return affected


func check_height_region(start: Vector2i, end: Vector2i, mode: int) -> bool:
	## Bounded 0x181fa0 model, mode 0/1 only. Out-of-world cells
	## are skipped; an empty intersection is vacuously true.
	assert(mode == 0 or mode == 1)
	var bounds: Rect2i = _intersection(start, end)
	var lowest: float = INF
	var highest: float = -INF
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var i: int = z * width + x
			if (words[i] & (1 << mode)) == 0:
				return false
			var height: float = base_heights[i]
			if mode == 0 and overlay_first_attributes[i] != INHERIT:
				height = overlay_heights[i]
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	return highest == -INF or highest - lowest <= HEIGHT_SPREAD_LIMIT


static func decode_navigation_byte(word: int) -> int:
	## Only the seven proven bits of 0x185e70 are modeled. Not a
	## complete NPC passability rule or a Godot collision mask.
	var result: int = 0
	for pair in [[8, 2], [9, 3], [10, 0], [11, 1], [13, 5], [14, 6]]:
		if (word & (1 << int(pair[0]))) != 0:
			result |= 1 << int(pair[1])
	if (word & (1 << 12)) != 0 and (word & BIT_REGION_6) == 0:
		result |= 1 << 4
	return result


func _intersection(start: Vector2i, end: Vector2i) -> Rect2i:
	## Caller supplies ascending inclusive corners; reversed rectangles
	## were not validated by RE, so intentionally reject them.
	assert(start.x <= end.x and start.y <= end.y)
	var min_x: int = clampi(start.x, 0, width)
	var min_z: int = clampi(start.y, 0, depth)
	var max_x: int = clampi(end.x + 1, 0, width)
	var max_z: int = clampi(end.y + 1, 0, depth)
	return Rect2i(min_x, min_z, maxi(0, max_x - min_x), maxi(0, max_z - min_z))
