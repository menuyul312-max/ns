class_name IslandComposer
extends RefCounted
## Authored runtime editing and persistence; unrelated to proprietary game formats.

const EDIT_MIN: int = 0
const EDIT_MAX: int = 5

var island: IslandDefinition
var strict_build_rules: bool = false
var protect_connectivity: bool = false
var last_edit_report: Dictionary = {"allowed": true, "code": "READY", "message": "Editor siap"}


func _init(initial: IslandDefinition = null) -> void:
	island = initial if initial != null else IslandDefinition.fixture_terraces()


func use_fixture(index: int) -> bool:
	match index:
		1:
			island = IslandDefinition.fixture_terraces()
		2:
			island = IslandDefinition.fixture_bend()
		3:
			island = IslandDefinition.fixture_river()
		4:
			island = IslandDefinition.fixture_coast_mask()
		_:
			return false
	last_edit_report = {"allowed": true, "code": "READY", "message": "Denah diganti"}
	return true


func modify_tile(x: int, z: int, difference: int) -> bool:
	if not island.is_land(x, z):
		return false
	var previous: int = island.height_at(x, z)
	var updated: int = clampi(previous + difference, EDIT_MIN, EDIT_MAX)
	if previous == updated:
		return false
	if not _check_build(x, z, "raise" if difference > 0 else "lower"):
		return false
	if not _check_link_support(x, z, updated, island.is_water(x, z)):
		return false
	if not _check_access(x, z, updated, island.is_water(x, z)):
		return false
	island.set_height(x, z, updated)
	last_edit_report = {"allowed": true, "code": "OK", "message": "Elevasi diperbarui"}
	return true


func toggle_water(x: int, z: int) -> bool:
	if not island.is_land(x, z):
		return false
	if not island.is_water(x, z) and island.occupant_at(x, z) != 0:
		last_edit_report = {"allowed": false, "code": "FEATURE_ON_WATER", "message": "Pindahkan pohon atau bangunan sebelum membuat alur air"}
		return false
	if not _check_build(x, z, "water_remove" if island.is_water(x, z) else "water_add"):
		return false
	if not _check_link_support(x, z, island.height_at(x, z), not island.is_water(x, z)):
		return false
	if not _check_access(x, z, island.height_at(x, z), not island.is_water(x, z)):
		return false
	island.set_water(x, z, not island.is_water(x, z))
	last_edit_report = {"allowed": true, "code": "OK", "message": "Jalur air diperbarui"}
	return true


func cycle_occupant(x: int, z: int) -> bool:
	if not island.is_land(x, z):
		return false
	if island.is_water(x, z):
		last_edit_report = {"allowed": false, "code": "FEATURE_ON_WATER", "message": "Pohon/bangunan tidak ditempatkan di tile air"}
		return false
	if island.connector_at(x, z) != 0:
		last_edit_report = {"allowed": false, "code": "LINK_OCCUPIED", "message": "Hapus ramp atau jembatan sebelum menempatkan objek"}
		return false
	var next: int = (island.occupant_at(x, z) + 1) % 3
	var near_connector: bool = false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			near_connector = near_connector or island.connector_at(x + dx, z + dz) != 0
	if near_connector:
		var occupied_copy := IslandDefinition.from_dictionary(island.as_dictionary())
		occupied_copy.set_occupant(x, z, next)
		if not IslandLinkRules.links_around_valid(occupied_copy, x, z):
			last_edit_report = {"allowed": false, "code": "LINK_LANDING", "message": "Ujung jembatan atau ramp harus bebas pohon dan bangunan"}
			return false
	island.set_occupant(x, z, next)
	last_edit_report = {"allowed": true, "code": "OK", "message": "Penanda pohon/bangunan diperbarui"}
	return true


func cycle_connector(x: int, z: int) -> bool:
	if not island.is_land(x, z):
		return false
	var existing: int = island.connector_at(x, z)
	var placement: Dictionary = IslandLinkRules.placement_report(island, x, z) if existing == 0 else {"kind": 0}
	var next: int = 0 if existing != 0 else int(placement.get("kind", 0))
	if existing == 0 and next == 0:
		last_edit_report = placement
		return false
	var changed_cells: Array[Vector2i] = [Vector2i(x, z)]
	if IslandLinkRules.is_bridge_kind(existing):
		var old_span: Dictionary = IslandLinkRules.bridge_span(island, x, z, existing, true)
		if not bool(old_span["valid"]):
			last_edit_report = {"allowed": false, "code": "LINK_CORRUPT", "message": "Bentangan lama tidak lengkap"}
			return false
		changed_cells = old_span["cells"]
	elif IslandLinkRules.is_bridge_kind(next):
		changed_cells = placement["cells"]
	if next != 0:
		var probe := IslandDefinition.from_dictionary(island.as_dictionary())
		for cell in changed_cells:
			probe.set_connector(cell.x, cell.y, next)
		for cell in changed_cells:
			if not IslandLinkRules.links_around_valid(probe, cell.x, cell.y):
				last_edit_report = {"allowed": false, "code": "LINK_CONFLICT", "message": "Lokasi berbenturan dengan ujung konektor lain"}
				return false
	if protect_connectivity:
		last_edit_report = IslandAccessAudit.preview_change(island, x, z, island.height_at(x, z), island.is_water(x, z), next, changed_cells)
		if not bool(last_edit_report["allowed"]):
			return false
	for cell in changed_cells:
		island.set_connector(cell.x, cell.y, next)
	var success_message: String = "Ramp dipasang"
	if next == 0:
		success_message = "Jembatan %d tile dihapus" % changed_cells.size() if IslandLinkRules.is_bridge_kind(existing) else "Connector dihapus"
	elif IslandLinkRules.is_bridge_kind(next):
		success_message = "Jembatan %d tile dipasang" % changed_cells.size()
	last_edit_report = {"allowed": true, "code": "OK", "message": success_message}
	return true


func _check_link_support(x: int, z: int, next_height: int, next_water: bool) -> bool:
	var has_link: bool = false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if island.connector_at(x + dx, z + dz) != 0:
				has_link = true
	if not has_link:
		return true
	var copy := IslandDefinition.from_dictionary(island.as_dictionary())
	copy.set_height(x, z, next_height)
	copy.set_water(x, z, next_water)
	if not IslandLinkRules.links_around_valid(copy, x, z):
		last_edit_report = {"allowed": false, "code": "LINK_SUPPORT", "message": "Hapus ramp/jembatan dahulu agar ujungnya tidak menggantung"}
		return false
	return true


func _check_build(x: int, z: int, action: String) -> bool:
	if not strict_build_rules:
		return true
	last_edit_report = IslandBuildRules.check(island, x, z, action)
	return bool(last_edit_report["allowed"])


func _check_access(x: int, z: int, next_height: int, next_water: bool) -> bool:
	if not protect_connectivity:
		return true
	last_edit_report = IslandAccessAudit.preview_change(island, x, z, next_height, next_water)
	return bool(last_edit_report["allowed"])


func cycle_terrain_layer(x: int, z: int, layer: int, field: String) -> bool:
	if not island.is_land(x, z) or layer < 0 or layer > 1:
		return false
	var original: Dictionary = island.terrain_layer_at(x, z, layer)
	var unit: int = original["unit"]
	var variation: int = original["variation"]
	var rotation: int = original["rotation"]
	match field:
		"unit":
			unit = (unit + 1) % 4
			variation = 0
		"variation":
			variation = (variation + 1) % (IslandDefinition.VISUAL_VARIATION_LIMITS[unit] + 1)
		"rotation":
			rotation = (rotation + 1) % 4
		_:
			return false
	island.set_terrain_layer(x, z, layer, unit, variation, rotation)
	last_edit_report = {"allowed": true, "code": "OK", "message": "Gaya tile diperbarui"}
	return true


func sculpt_coast(side: int, index: int, step: float) -> bool:
	if side < 0 or side > 3 or index < 0 or index >= island.shore_profiles[side].size():
		last_edit_report = {"allowed": false, "code": "COAST_OUTSIDE", "message": "Titik garis pantai di luar denah"}
		return false
	var previous: float = island.shore_profiles[side][index]
	if not island.set_coast_inset(side, index, previous + step):
		last_edit_report = {"allowed": false, "code": "COAST_CORNER", "message": "Sudut pantai dikunci agar sambungan tetap utuh"}
		return false
	var next_value: float = island.shore_profiles[side][index]
	if is_equal_approx(next_value, previous):
		return false
	last_edit_report = {"allowed": true, "code": "OK", "message": "Profil pesisir %.2fm" % next_value}
	return true


func set_land_presence(x: int, z: int, enabled: bool) -> bool:
	if not island.contains(x, z):
		last_edit_report = {"allowed": false, "code": "MASK_OUTSIDE", "message": "Di luar denah pulau"}
		return false
	if island.is_land(x, z) == enabled:
		return false
	if not enabled:
		if island.land_mask.count(1) <= 1:
			last_edit_report = {"allowed": false, "code": "LAST_LAND", "message": "Pulau harus mempunyai setidaknya satu sel darat"}
			return false
		if island.height_at(x, z) != 0 or island.is_water(x, z) or island.occupant_at(x, z) != 0 or island.connector_at(x, z) != 0:
			last_edit_report = {"allowed": false, "code": "MASK_OCCUPIED", "message": "Hanya tanah datar kosong yang bisa diubah menjadi laut"}
			return false
		var probe := IslandDefinition.from_dictionary(island.as_dictionary())
		probe.set_land(x, z, false)
		if not IslandLinkRules.links_around_valid(probe, x, z):
			last_edit_report = {"allowed": false, "code": "MASK_LINK", "message": "Tepi menopang ramp atau jembatan aktif"}
			return false
	if protect_connectivity:
		last_edit_report = IslandAccessAudit.preview_mask_change(island, x, z, enabled)
		if not bool(last_edit_report["allowed"]):
			return false
	island.set_land(x, z, enabled)
	last_edit_report = {"allowed": true, "code": "OK", "message": "Pulau ditambah" if enabled else "Teluk/laut dibentuk"}
	return true


func set_land_area(center_x: int, center_z: int, enabled: bool, radius: int = 1) -> bool:
	# ACNH's RE table lists 1x1 and 3x3 landmaking action ranges; this is
	# OUR atomic brush implementation, not a native brush algorithm.
	# Work on a complete candidate so a failed tile/connector/connectivity
	# rule never leaves behind a partial crater or unsupported land bridge.
	if radius < 0 or radius > 1:
		last_edit_report = {"allowed": false, "code": "BRUSH_RANGE", "message": "Brush hanya mendukung 1×1 atau 3×3"}
		return false
	for z in range(center_z - radius, center_z + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if not island.contains(x, z):
				last_edit_report = {"allowed": false, "code": "BRUSH_OUTSIDE", "message": "Brush melewati batas denah"}
				return false
	var preview := IslandComposer.new(IslandDefinition.from_dictionary(island.as_dictionary()))
	preview.strict_build_rules = strict_build_rules
	preview.protect_connectivity = protect_connectivity
	var changed: int = 0
	for z in range(center_z - radius, center_z + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if preview.island.is_land(x, z) == enabled:
				continue
			if not preview.set_land_presence(x, z, enabled):
				last_edit_report = preview.last_edit_report.duplicate()
				last_edit_report["message"] = "Brush gagal pada (%d,%d): %s" % [x, z, str(last_edit_report.get("message", ""))]
				return false
			changed += 1
	if changed == 0:
		last_edit_report = {"allowed": false, "code": "BRUSH_NO_CHANGE", "message": "Semua tile sudah sesuai"}
		return false
	island = preview.island
	last_edit_report = {"allowed": true, "code": "OK", "message": "%d tile pesisir diperbarui secara atomik" % changed}
	return true


func save_layout(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(island.as_dictionary(), "\t"))
	file.close()
	return true


func load_layout(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var candidate: Dictionary = parsed
	var version: int = int(candidate.get("schema_version", 0))
	if (version < 1 or version > 7) or not candidate.has("width") or not candidate.has("depth") or not candidate.has("levels"):
		return false
	var width: int = int(candidate["width"])
	var depth: int = int(candidate["depth"])
	if width < 1 or width > 128 or depth < 1 or depth > 128 or not candidate["levels"] is Array:
		return false
	var values: Array = candidate["levels"]
	if values.size() != width * depth:
		return false
	for item in values:
		if not item is float and not item is int:
			return false
		if float(item) != float(int(item)) or int(item) < EDIT_MIN or int(item) > EDIT_MAX:
			return false
	if version >= 2:
		if not candidate.has("water") or not candidate["water"] is Array:
			return false
		var cells: Array = candidate["water"]
		if cells.size() != width * depth:
			return false
		for cell in cells:
			if not cell is float and not cell is int:
				return false
			if int(cell) != 0 and int(cell) != 1:
				return false
	if version >= 3:
		if not candidate.has("terrain_layers") or not candidate["terrain_layers"] is Array or candidate["terrain_layers"].size() != 2:
			return false
		for layer_data in candidate["terrain_layers"]:
			if not layer_data is Dictionary:
				return false
			for field in ["unit", "variation", "rotation"]:
				if not layer_data.has(field) or not layer_data[field] is Array or layer_data[field].size() != width * depth:
					return false
				for value in layer_data[field]:
					if not value is int and not value is float:
						return false
					if float(value) != float(int(value)) or int(value) < 0 or int(value) > 3:
						return false
	if version >= 4:
		if not candidate.has("occupants") or not candidate["occupants"] is Array or candidate["occupants"].size() != width * depth:
			return false
		for index in range(width * depth):
			var occupant_value: Variant = candidate["occupants"][index]
			if not occupant_value is int and not occupant_value is float:
				return false
			if float(occupant_value) != float(int(occupant_value)) or int(occupant_value) < 0 or int(occupant_value) > 2:
				return false
			if int(occupant_value) != 0 and int(candidate["water"][index]) != 0:
				return false
	if version >= 5:
		if not candidate.has("connectors") or not candidate["connectors"] is Array or candidate["connectors"].size() != width * depth:
			return false
		for link_value in candidate["connectors"]:
			if not link_value is int and not link_value is float:
				return false
			if float(link_value) != float(int(link_value)) or int(link_value) < 0 or int(link_value) > 6:
				return false
	if version >= 6:
		if not candidate.has("shore_profiles") or not candidate["shore_profiles"] is Array or candidate["shore_profiles"].size() != 4:
			return false
		for side in range(4):
			var row: Variant = candidate["shore_profiles"][side]
			var expected: int = depth + 1 if side < 2 else width + 1
			if not row is Array or row.size() != expected:
				return false
			for index in range(row.size()):
				var value: Variant = row[index]
				if (not value is int and not value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.10:
					return false
				if (index == 0 or index == row.size() - 1) and not is_zero_approx(float(value)):
					return false
	if version >= 7:
		if not candidate.has("land_mask") or not candidate["land_mask"] is Array or candidate["land_mask"].size() != width * depth:
			return false
		var present_count: int = 0
		for index in range(width * depth):
			var presence: Variant = candidate["land_mask"][index]
			if (not presence is int and not presence is float) or float(presence) != float(int(presence)) or int(presence) not in [0, 1]:
				return false
			if int(presence) == 1:
				present_count += 1
			else:
				if int(candidate["levels"][index]) != 0 or int(candidate["water"][index]) != 0 or int(candidate["occupants"][index]) != 0 or int(candidate["connectors"][index]) != 0:
					return false
		if present_count == 0:
			return false
	var loaded := IslandDefinition.from_dictionary(candidate)
	for z in range(loaded.depth):
		for x in range(loaded.width):
			if not IslandLinkRules.is_valid(loaded, x, z, loaded.connector_at(x, z)):
				return false
	island = loaded
	last_edit_report = {"allowed": true, "code": "OK", "message": "Denah dimuat"}
	return true
