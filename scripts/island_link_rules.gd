class_name IslandLinkRules
extends RefCounted
## New Nusantara connector model, never claimed to match ACNH link data.
## 1..4: ramp in low dry tile toward a high dry neighbor (N/E/S/W).
## 5/6: a continuous 1..3-water-tile bridge spanning E/W or N/S.
## Each wet tile keeps its axis marker in schema v5; the physical deck is one span.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MAX_BRIDGE_SPAN: int = 3


static func direction_for_ramp(kind: int) -> Vector2i:
	return DIRS[kind - 1] if kind >= 1 and kind <= 4 else Vector2i.ZERO


static func is_bridge_kind(kind: int) -> bool:
	return kind == 5 or kind == 6


static func is_valid(island: IslandDefinition, x: int, z: int, kind: int) -> bool:
	if kind == 0:
		return true
	if not island.is_land(x, z) or island.occupant_at(x, z) != 0:
		return false
	if kind >= 1 and kind <= 4:
		if island.is_water(x, z):
			return false
		var toward: Vector2i = direction_for_ramp(kind)
		var adjacent: Vector2i = Vector2i(x, z) + toward
		return island.is_land(adjacent.x, adjacent.y) and not island.is_water(adjacent.x, adjacent.y) and island.height_at(adjacent.x, adjacent.y) == island.height_at(x, z) + 1 and island.occupant_at(adjacent.x, adjacent.y) == 0 and island.connector_at(adjacent.x, adjacent.y) == 0
	if is_bridge_kind(kind):
		return bool(bridge_span(island, x, z, kind, true)["valid"])
	return false


static func bridge_span(island: IslandDefinition, x: int, z: int, kind: int, require_active: bool) -> Dictionary:
	if not is_bridge_kind(kind) or not island.contains(x, z) or not island.is_water(x, z):
		return {"valid": false, "code": "NO_BANK_PAIR", "message": "Jembatan hanya dapat melintasi tile air"}
	var axis := Vector2i.RIGHT if kind == 5 else Vector2i.DOWN
	var first := Vector2i(x, z)
	while island.contains(first.x - axis.x, first.y - axis.y) and island.is_water(first.x - axis.x, first.y - axis.y):
		first -= axis
	var cells: Array[Vector2i] = []
	var next_cell: Vector2i = first
	while island.contains(next_cell.x, next_cell.y) and island.is_water(next_cell.x, next_cell.y):
		cells.append(next_cell)
		if cells.size() > MAX_BRIDGE_SPAN:
			return {"valid": false, "code": "SPAN_TOO_LONG", "message": "Bentangan prototipe maksimal tiga tile air"}
		next_cell += axis
	var before: Vector2i = first - axis
	var after: Vector2i = next_cell
	if not island.is_land(before.x, before.y) or not island.is_land(after.x, after.y) or island.is_water(before.x, before.y) or island.is_water(after.x, after.y):
		return {"valid": false, "code": "NO_BANK_PAIR", "message": "Bentangan memerlukan dua tepian kering"}
	var level: int = island.height_at(x, z)
	if island.height_at(before.x, before.y) != level or island.height_at(after.x, after.y) != level:
		return {"valid": false, "code": "BANK_LEVEL", "message": "Kedua tepian dan permukaan air harus berada di elevasi yang sama"}
	if island.occupant_at(before.x, before.y) != 0 or island.occupant_at(after.x, after.y) != 0 or island.connector_at(before.x, before.y) != 0 or island.connector_at(after.x, after.y) != 0:
		return {"valid": false, "code": "BANK_BLOCKED", "message": "Kosongkan kedua tepian sebelum memasang jembatan"}
	for cell in cells:
		if island.height_at(cell.x, cell.y) != level:
			return {"valid": false, "code": "BANK_LEVEL", "message": "Elevasi permukaan air pada seluruh bentangan harus sama"}
		var marker: int = island.connector_at(cell.x, cell.y)
		if (require_active and marker != kind) or (not require_active and marker != 0):
			return {"valid": false, "code": "LINK_CONFLICT", "message": "Seluruh tile air dalam satu bentangan harus menggunakan satu konektor"}
	return {"valid": true, "code": "OK", "message": "Bentangan valid", "cells": cells, "first": first, "last": cells.back(), "kind": kind, "axis": axis}


static func placement_report(island: IslandDefinition, x: int, z: int) -> Dictionary:
	if not island.is_land(x, z):
		return {"allowed": false, "code": "OUT_OF_BOUNDS", "message": "Di luar batas pulau"}
	if island.occupant_at(x, z) != 0:
		return {"allowed": false, "code": "SITE_OCCUPIED", "message": "Pindahkan pohon atau bangunan dari lokasi konektor"}
	var candidate: int = find_new(island, x, z)
	if candidate != 0:
		var result: Dictionary = {"allowed": true, "code": "OK", "kind": candidate, "message": "Lokasi konektor valid"}
		if is_bridge_kind(candidate):
			result["cells"] = bridge_span(island, x, z, candidate, false)["cells"]
		return result
	if island.is_water(x, z):
		var failure: Dictionary = {"valid": false, "code": "NO_BANK_PAIR", "message": "Perlu dua tepian kering pada ujung bentangan"}
		for bridge_kind in [5, 6]:
			var option: Dictionary = bridge_span(island, x, z, bridge_kind, false)
			if option["code"] != "NO_BANK_PAIR":
				failure = option
		return {"allowed": false, "code": failure["code"], "message": failure["message"]}
	for axis in DIRS:
		var high: Vector2i = Vector2i(x, z) + axis
		if island.contains(high.x, high.y) and not island.is_water(high.x, high.y) and island.height_at(high.x, high.y) == island.height_at(x, z) + 1:
			if island.occupant_at(high.x, high.y) != 0 or island.connector_at(high.x, high.y) != 0:
				return {"allowed": false, "code": "RAMP_LANDING_BLOCKED", "message": "Kosongkan dataran atas pada ujung ramp"}
	return {"allowed": false, "code": "NO_CLIFF_STEP", "message": "Ramp memerlukan tebing kering dengan beda tepat satu elevasi"}


static func find_new(island: IslandDefinition, x: int, z: int) -> int:
	if island.is_water(x, z):
		for candidate in [5, 6]:
			if bool(bridge_span(island, x, z, candidate, false)["valid"]):
				return candidate
	else:
		for candidate in [1, 2, 3, 4]:
			if is_valid(island, x, z, candidate):
				return candidate
	return 0


static func is_walk_node(island: IslandDefinition, cell: Vector2i) -> bool:
	if not island.is_land(cell.x, cell.y):
		return false
	if not island.is_water(cell.x, cell.y):
		return true
	var kind: int = island.connector_at(cell.x, cell.y)
	return is_bridge_kind(kind) and is_valid(island, cell.x, cell.y, kind)


static func walk_edge(island: IslandDefinition, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not is_walk_node(island, from_cell) or not is_walk_node(island, to_cell):
		return false
	var difference: Vector2i = to_cell - from_cell
	if absi(difference.x) + absi(difference.y) != 1:
		return false
	var from_level: int = island.height_at(from_cell.x, from_cell.y)
	var to_level: int = island.height_at(to_cell.x, to_cell.y)
	if from_level == to_level:
		# Bridges are one-cell crossings, not wide paths that join side banks.
		if island.is_water(from_cell.x, from_cell.y) or island.is_water(to_cell.x, to_cell.y):
			var bridge_cell: Vector2i = from_cell if island.is_water(from_cell.x, from_cell.y) else to_cell
			var bridge_kind: int = island.connector_at(bridge_cell.x, bridge_cell.y)
			return (bridge_kind == 5 and difference.y == 0) or (bridge_kind == 6 and difference.x == 0)
		return true
	# A height transition is possible only through an explicit ramp in the low tile.
	var low: Vector2i = from_cell if from_level < to_level else to_cell
	var high: Vector2i = to_cell if from_level < to_level else from_cell
	if abs(from_level - to_level) != 1:
		return false
	var ramp_kind: int = island.connector_at(low.x, low.y)
	return is_valid(island, low.x, low.y, ramp_kind) and ramp_kind >= 1 and ramp_kind <= 4 and low + direction_for_ramp(ramp_kind) == high


static func on_bridge_deck(island: IslandDefinition, px: float, pz: float) -> bool:
	var x: int = floori(px / IslandDefinition.TILE_SIZE)
	var z: int = floori(pz / IslandDefinition.TILE_SIZE)
	# The short approach lips lie on the dry bank, so include the bridge's
	# immediate neighbors. This matches the actual collider's extension.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bx: int = x + dx
			var bz: int = z + dz
			var kind: int = island.connector_at(bx, bz)
			if not is_bridge_kind(kind) or not is_valid(island, bx, bz, kind):
				continue
			var u: float = px / IslandDefinition.TILE_SIZE - (float(bx) + 0.5)
			var v: float = pz / IslandDefinition.TILE_SIZE - (float(bz) + 0.5)
			if kind == 5 and absf(v) < 0.37 and absf(u) < 0.64:
				return true
			if kind == 6 and absf(u) < 0.37 and absf(v) < 0.64:
				return true
	return false


static func links_around_valid(island: IslandDefinition, x: int, z: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var nx: int = x + dx
			var nz: int = z + dz
			if not island.contains(nx, nz):
				continue
			var kind: int = island.connector_at(nx, nz)
			if not is_valid(island, nx, nz, kind):
				return false
	return true


static func ramp_opens_cliff(island: IslandDefinition, high_x: int, high_z: int, side_index: int) -> bool:
	var low: Vector2i = Vector2i(high_x, high_z) + DIRS[side_index]
	var kind: int = island.connector_at(low.x, low.y)
	return kind >= 1 and kind <= 4 and is_valid(island, low.x, low.y, kind) and low + direction_for_ramp(kind) == Vector2i(high_x, high_z)
