class_name NativeTerrainReference
extends RefCounted
## Research-only, clean-room implementation of the bounded native terrain
## contracts documented in menuyul312-max/acnh-re-results (ACNH 1.0.0).
## It does NOT use Nintendo code, maps, textures, or binary structs, and does
## NOT imply that ACNH coordinates equal our Godot world units.

const CELL_SIZE: float = 5.0
const HALF_CELL: float = 2.5
const QUARTER_CELL: float = 1.25
const INHERIT: int = 7


static func cell_center(index: Vector2i) -> Vector2:
	return Vector2(float(index.x) * CELL_SIZE + HALF_CELL, float(index.y) * CELL_SIZE + HALF_CELL)


static func native_index(value: float) -> int:
	# Source: docs/TERRAIN_RUNTIME.md, ELF 0x52b280. The double truncation
	# and negative correction are deliberate. floor(-10/5) would be WRONG.
	# Bounded finite inputs only; ACNH f32 edge behavior outside that domain
	# is not represented by GDScript's usual 64-bit float arithmetic.
	return int(float(int(value)) / CELL_SIZE) - (1 if value < 0.0 else 0)


static func sector(u: float, v: float) -> int:
	# Source: docs/FOCUS7_MECHANICS.md, ELF 0x18adf0.
	# Four triangular sectors, NOT the four cartesian quadrants.
	var a: float = v - u
	var b: float = u + v - CELL_SIZE
	if a >= 0.0:
		return 2 if b >= 0.0 else 1
	return 3 if b >= 0.0 else 0


static func four_points(index: Vector2i) -> Array[Vector2]:
	# Source: docs/TERRAIN_RUNTIME.md, ELF 0x162dc0. Clockwise order
	# is north, west, south, east in the native x/z plane.
	var center: Vector2 = cell_center(index)
	return [
		center + Vector2(0.0, -QUARTER_CELL),
		center + Vector2(-QUARTER_CELL, 0.0),
		center + Vector2(0.0, QUARTER_CELL),
		center + Vector2(QUARTER_CELL, 0.0)
	]


static func attribute_at(world: Vector2, origin_index: Vector2i, width: int, depth: int, base: PackedByteArray, overlay: PackedByteArray) -> int:
	# Our compact test view stores four sector bytes in record order.
	# ACNH's verified *runtime* record stride is 52 bytes with attributes
	# at offsets 48..51; this compact buffer is not its binary ABI.
	if width <= 0 or depth <= 0 or base.size() != width * depth * 4:
		return INHERIT
	var local: Vector2 = world - Vector2(origin_index) * CELL_SIZE
	var x: int = native_index(local.x)
	var z: int = native_index(local.y)
	if x < 0 or z < 0 or x >= width or z >= depth:
		return INHERIT
	var u: float = local.x - float(x) * CELL_SIZE
	var v: float = local.y - float(z) * CELL_SIZE
	var offset: int = (z * width + x) * 4 + sector(u, v)
	var value: int = base[offset]
	if offset < overlay.size() and overlay[offset] != INHERIT:
		value = overlay[offset]
	return value


static func sample_four(index: Vector2i, origin_index: Vector2i, width: int, depth: int, base: PackedByteArray, overlay: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	for point in four_points(index):
		result.append(attribute_at(point, origin_index, width, depth, base, overlay))
	return result


static func all_four_match(flags: PackedByteArray) -> bool:
	if flags.size() != 4:
		return false
	for flag in flags:
		if flag == 0:
			return false
	return true


static func any_four_match(flags: PackedByteArray) -> bool:
	if flags.size() != 4:
		return false
	for flag in flags:
		if flag != 0:
			return true
	return false


static func exactly_two_match(flags: PackedByteArray) -> bool:
	return flags.size() == 4 and flags.count(1) == 2
