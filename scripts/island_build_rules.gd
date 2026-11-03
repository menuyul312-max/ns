class_name IslandBuildRules
extends RefCounted
## Optional, original Nusantara editing guards.
## RE FieldLandMakingError has 12 named error categories, but does NOT prove
## their complete boolean predicates, distances, or priority. This is a
## gameplay design experiment with a visible ON/OFF switch, not an ACNH port.

const CONTEXT_RADIUS: int = 1  # Three-by-three sample; native action range is not decoded as a brush.
const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func check(island: IslandDefinition, x: int, z: int, action: String) -> Dictionary:
	if not island.contains(x, z):
		return _denied("OUTSIDE_MAP", "Di luar batas pulau")
	if not ["raise", "lower", "water_add", "water_remove"].has(action):
		return _denied("UNKNOWN_ACTION", "Aksi belum dikenali")
	if action == "water_remove":
		return _allowed()
	var own_feature: int = island.occupant_at(x, z)
	if own_feature != 0:
		return _denied("OCCUPIED_TILE", "Pindahkan pohon/bangunan sebelum mengubah tanah atau air")
	# Inspect a 3x3 CONTEXT, without touching all nine cells. The original
	# table exposes a 3x3 action range, not proof of a nine-tile brush.
	for offset_z in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
		for offset_x in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
			if offset_x == 0 and offset_z == 0:
				continue
			var nx: int = x + offset_x
			var nz: int = z + offset_z
			if not island.contains(nx, nz):
				continue
			var feature: int = island.occupant_at(nx, nz)
			if feature == 1:
				return _denied("TREE_NEAR_EDIT", "Terlalu dekat pohon pada area pemeriksaan")
			if feature == 2:
				return _denied("BUILDING_NEAR_EDIT", "Terlalu dekat bangunan pada area pemeriksaan")
	if action == "lower" and _water_within_context(island, x, z):
		return _denied("CLIFF_NEAR_WATER", "Tebing tidak diturunkan di dekat air pada mode aman")
	if _waterfall_within_context(island, x, z):
		return _denied("WATERFALL_NEAR_EDIT", "Pindahkan edit menjauh dari pertemuan air terjun")
	return _allowed()


static func _water_within_context(island: IslandDefinition, x: int, z: int) -> bool:
	for dz in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
		for dx in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
			if island.is_water(x + dx, z + dz):
				return true
	return false


static func _waterfall_within_context(island: IslandDefinition, x: int, z: int) -> bool:
	for dz in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
		for dx in range(-CONTEXT_RADIUS, CONTEXT_RADIUS + 1):
			var nx: int = x + dx
			var nz: int = z + dz
			if not island.is_water(nx, nz):
				continue
			for direction in CARDINALS:
				var adjacent: Vector2i = Vector2i(nx, nz) + direction
				if island.is_water(adjacent.x, adjacent.y) and island.height_at(nx, nz) != island.height_at(adjacent.x, adjacent.y):
					return true
	return false


static func _denied(code: String, message: String) -> Dictionary:
	return {"allowed": false, "code": code, "message": message, "source": "nusantara_experimental_rule"}


static func _allowed() -> Dictionary:
	return {"allowed": true, "code": "OK", "message": "Pemeriksaan lokasi diterima", "source": "nusantara_experimental_rule"}
