class_name IslandCoastLoops
extends RefCounted
## Sprint 43: deterministic global rings around occupied land-mask cells.
## Topology audit/mesh-design input ONLY. The existing warped TerrainBuilder
## meshes and collision remain authoritative until a watertight polygon mesh
## can be verified in a real Godot runtime.


static func trace(island: IslandDefinition) -> Dictionary:
	var edges: Array[Dictionary] = []
	var outgoing: Dictionary = {}
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_land(x, z):
				continue
			# Directed clockwise in map X/Z coordinates: land on the right.
			if not island.is_land(x, z - 1):
				_append(edges, outgoing, Vector2i(x, z), Vector2i(x + 1, z))
			if not island.is_land(x + 1, z):
				_append(edges, outgoing, Vector2i(x + 1, z), Vector2i(x + 1, z + 1))
			if not island.is_land(x, z + 1):
				_append(edges, outgoing, Vector2i(x + 1, z + 1), Vector2i(x, z + 1))
			if not island.is_land(x - 1, z):
				_append(edges, outgoing, Vector2i(x, z + 1), Vector2i(x, z))

	var visited := PackedByteArray()
	visited.resize(edges.size())
	visited.fill(0)
	var rings: Array[Dictionary] = []
	var broken: int = 0
	var perimeter: float = 0.0
	var signed_area: float = 0.0
	var unit: float = IslandDefinition.TILE_SIZE
	for first in range(edges.size()):
		if visited[first] != 0:
			continue
		var ring := PackedVector2Array()
		var cursor: int = first
		var begin: Vector2i = edges[first]["a"]
		var closed: bool = false
		for _step in range(edges.size() + 1):
			if visited[cursor] != 0:
				break
			visited[cursor] = 1
			var a: Vector2i = edges[cursor]["a"]
			var b: Vector2i = edges[cursor]["b"]
			ring.append(Vector2(float(a.x) * unit, float(a.y) * unit))
			if b == begin:
				closed = true
				break
			cursor = _choose_next(edges, outgoing, visited, a, b)
			if cursor < 0:
				break
		if not closed:
			broken += 1
			continue
		var area: float = _signed_area(ring)
		var length: float = _perimeter(ring)
		signed_area += area
		perimeter += length
		rings.append({
			"points": ring,
			"hole": area < 0.0,
			"area_tiles": area / (unit * unit),
			"perimeter_world": length,
			"vertex_count": ring.size(),
		})
	var islands: int = 0
	var holes: int = 0
	for ring in rings:
		if ring["hole"]:
			holes += 1
		else:
			islands += 1
	return {
		"rings": rings,
		"islands": islands,
		"holes": holes,
		"broken_chains": broken,
		"boundary_edges": edges.size(),
		"signed_area_world": signed_area,
		"perimeter_world": perimeter,
	}


static func _append(edges: Array[Dictionary], outgoing: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var index: int = edges.size()
	edges.append({"a": a, "b": b})
	var starts: Array = outgoing.get(a, [])
	starts.append(index)
	outgoing[a] = starts


static func _choose_next(edges: Array[Dictionary], outgoing: Dictionary, visited: PackedByteArray, a: Vector2i, b: Vector2i) -> int:
	var incoming: Vector2i = b - a
	var right := Vector2i(-incoming.y, incoming.x)
	var left := Vector2i(incoming.y, -incoming.x)
	var candidate: int = -1
	var best_priority: int = 9
	for edge_index in outgoing.get(b, []):
		if visited[edge_index] != 0:
			continue
		var candidate_dir: Vector2i = edges[edge_index]["b"] - b
		var priority: int = 0 if candidate_dir == right else (1 if candidate_dir == incoming else (2 if candidate_dir == left else 3))
		if priority < best_priority:
			candidate = edge_index
			best_priority = priority
	return candidate


static func _signed_area(points: PackedVector2Array) -> float:
	var result: float = 0.0
	for index in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		result += a.x * b.y - b.x * a.y
	return result * 0.5


static func _perimeter(points: PackedVector2Array) -> float:
	var result: float = 0.0
	for index in range(points.size()):
		result += points[index].distance_to(points[(index + 1) % points.size()])
	return result
