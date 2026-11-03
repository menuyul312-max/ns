class_name CoastContour
extends RefCounted
## Deterministic edge relief shared by terrain render and terrain collision.
## The logical grid stays rectangular; perimeter vertices use editable profiles.

const EDGE_INFLUENCE: float = 1.90
const FIRST_AMPLITUDE: float = 0.34
const SECOND_AMPLITUDE: float = 0.135
## A mesh vertex on the authored outer coast may move beyond the original
## rectangular grid. Keep the shoreline test's initial guard wide enough to
## include sculpt inset + both harmonics + the mask-seam contribution.
const OUTER_WARP_GUARD: float = 2.40

## Sprint 36/37: nearby actual shoreline segments indexed in tile-size bins.
## Rebuilt when topology, river suppression or edge sculpt changes. The cache
## stores 2D reference polylines only; it never changes the collider itself.
static var _shore_cache_instance: int = -1
static var _shore_cache_revision: int = -1
static var _shore_cache_has_holes: bool = false
static var _shore_segments_by_bin: Dictionary = {}


static func prepare_shoreline_cache(island: IslandDefinition) -> void:
	if _shore_cache_instance == island.get_instance_id() and _shore_cache_revision == island.coastline_revision:
		return
	_shore_cache_instance = island.get_instance_id()
	_shore_cache_revision = island.coastline_revision
	_shore_cache_has_holes = island.land_mask.count(0) > 0
	_shore_segments_by_bin.clear()
	if not _shore_cache_has_holes:
		return
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_land(x, z) or island.height_at(x, z) != 0:
				continue
			var rounded: Array[bool] = [false, false, false, false]
			for corner in range(4):
				rounded[corner] = TerrainBuilder._is_mask_corner(island, x, z, corner)
			for direction in range(4):
				var adjacent: Vector2i = Vector2i(x, z - 1) if direction == 0 else (Vector2i(x + 1, z) if direction == 1 else (Vector2i(x, z + 1) if direction == 2 else Vector2i(x - 1, z)))
				if not island.contains(adjacent.x, adjacent.y) or island.is_land(adjacent.x, adjacent.y):
					continue
				var bounds: Vector2 = TerrainBuilder._shore_edge_bounds(island, x, z, direction, rounded)
				if bounds.y <= bounds.x:
					continue
				var previous_edge: Vector2 = _warped_point(island, TerrainBuilder._edge_position(x, z, direction, bounds.x, 0.0, 0.0))
				for segment in range(1, TerrainBuilder.EDGE_SUBDIVISIONS + 1):
					var t: float = lerpf(bounds.x, bounds.y, float(segment) / float(TerrainBuilder.EDGE_SUBDIVISIONS))
					var next: Vector2 = _warped_point(island, TerrainBuilder._edge_position(x, z, direction, t, 0.0, 0.0))
					_store_shore_segment(previous_edge, next)
					previous_edge = next
			for corner in range(4):
				if not rounded[corner]:
					continue
				var previous_arc: Vector2 = _warped_point(island, TerrainBuilder._corner_arc_position(x, z, corner, 0.0, 0.0, 0.0, TerrainBuilder.MASK_CORNER_RADIUS))
				for segment in range(1, TerrainBuilder.CORNER_SUBDIVISIONS + 1):
					var next: Vector2 = _warped_point(island, TerrainBuilder._corner_arc_position(x, z, corner, float(segment) / float(TerrainBuilder.CORNER_SUBDIVISIONS), 0.0, 0.0, TerrainBuilder.MASK_CORNER_RADIUS))
					_store_shore_segment(previous_arc, next)
					previous_arc = next
	# Reentrant arcs are in missing cells, not in the land-tile side skirts.
	for z in range(island.depth):
		for x in range(island.width):
			if island.is_land(x, z):
				continue
			for corner in range(4):
				if not TerrainBuilder._is_concave_mask_corner(island, x, z, corner):
					continue
				var previous_fillet: Vector2 = _warped_point(island, TerrainBuilder._concave_arc_point(x, z, corner, 0.0))
				for segment in range(1, TerrainBuilder.CORNER_SUBDIVISIONS + 1):
					var next: Vector2 = _warped_point(island, TerrainBuilder._concave_arc_point(x, z, corner, float(segment) / float(TerrainBuilder.CORNER_SUBDIVISIONS)))
					_store_shore_segment(previous_fillet, next)
					previous_fillet = next


static func _warped_point(island: IslandDefinition, point: Vector3) -> Vector2:
	var result: Vector3 = warp_ground(island, point, 0)
	return Vector2(result.x, result.z)


static func _store_shore_segment(a: Vector2, b: Vector2) -> void:
	# Every covered bucket is surrounded by a two-tile halo. Beach blend falls
	# to zero beyond 3.35 world units, so lookup never needs a global scan.
	var tile: float = IslandDefinition.TILE_SIZE
	var min_x: int = floori(minf(a.x, b.x) / tile) - 2
	var max_x: int = floori(maxf(a.x, b.x) / tile) + 2
	var min_z: int = floori(minf(a.y, b.y) / tile) - 2
	var max_z: int = floori(maxf(a.y, b.y) / tile) + 2
	for bz in range(min_z, max_z + 1):
		for bx in range(min_x, max_x + 1):
			var key := Vector2i(bx, bz)
			var points: Array = _shore_segments_by_bin.get(key, [])
			points.append(a)
			points.append(b)
			_shore_segments_by_bin[key] = points


static func _point_to_segment_squared(point: Vector2, a: Vector2, b: Vector2) -> float:
	var edge: Vector2 = b - a
	var length_squared: float = edge.length_squared()
	if length_squared <= 0.0000001:
		return point.distance_squared_to(a)
	var t: float = clampf((point - a).dot(edge) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + edge * t)


static func warp_ground(island: IslandDefinition, position: Vector3, level: int) -> Vector3:
	if level != 0:
		return position
	var width: float = float(island.width) * IslandDefinition.TILE_SIZE
	var depth: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var left: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, position.x)
	var right: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, width - position.x)
	var north: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, position.z)
	var south: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, depth - position.z)
	var has_outer_edge: bool = maxf(maxf(left, right), maxf(north, south)) >= 0.00001
	var has_mask_edge: bool = _near_mask_seam(island, position.x, position.z)
	if not has_outer_edge and not has_mask_edge:
		return position
	# At freshwater outlets keep the waterbed border aligned with the shared
	# river contour so no gap opens between the meshes.
	var wet: float = RiverContour.field_at(island, position.x, position.z, 0)
	var dry_strength: float = 1.0 - smoothstep(0.20, 0.76, wet)
	var phase: float = float(island.seed % 307) * 0.019
	var offset_x: float = (FIRST_AMPLITUDE * sin(position.z * 0.43 + phase)
		+ SECOND_AMPLITUDE * sin(position.z * 1.17 - phase * 0.79))
	var offset_z: float = (FIRST_AMPLITUDE * sin(position.x * 0.47 - phase * 1.23)
		+ SECOND_AMPLITUDE * sin(position.x * 1.21 + phase * 0.51))
	position.x += (left - right) * offset_x * dry_strength
	position.z += (north - south) * offset_z * dry_strength
	position.x += (left * island.coast_inset_at(0, position.z) - right * island.coast_inset_at(1, position.z)) * dry_strength
	position.z += (north * island.coast_inset_at(2, position.x) - south * island.coast_inset_at(3, position.x)) * dry_strength
	if has_mask_edge:
		position += _mask_seam_offset(island, position, dry_strength)
	return position


static func _near_mask_seam(island: IslandDefinition, x: float, z: float) -> bool:
	var tile: float = IslandDefinition.TILE_SIZE
	var edge_x: int = roundi(x / tile)
	var edge_z: int = roundi(z / tile)
	var row: int = floori(z / tile)
	var column: int = floori(x / tile)
	if edge_x > 0 and edge_x < island.width and row >= 0 and row < island.depth and absf(x - float(edge_x) * tile) < EDGE_INFLUENCE:
		if island.is_land(edge_x - 1, row) != island.is_land(edge_x, row):
			return true
	if edge_z > 0 and edge_z < island.depth and column >= 0 and column < island.width and absf(z - float(edge_z) * tile) < EDGE_INFLUENCE:
		if island.is_land(column, edge_z - 1) != island.is_land(column, edge_z):
			return true
	return false


static func _mask_seam_offset(island: IslandDefinition, point: Vector3, strength: float) -> Vector3:
	var tile: float = IslandDefinition.TILE_SIZE
	var edge_x: int = roundi(point.x / tile)
	var edge_z: int = roundi(point.z / tile)
	var row: int = floori(point.z / tile)
	var column: int = floori(point.x / tile)
	var seed_phase: float = float(island.seed % 101) * 0.031
	var displacement := Vector3.ZERO
	if edge_x > 0 and edge_x < island.width and row >= 0 and row < island.depth:
		var west_land: bool = island.is_land(edge_x - 1, row)
		var east_land: bool = island.is_land(edge_x, row)
		if west_land != east_land:
			var along: float = clampf(point.z / tile - float(row), 0.0, 1.0)
			var prev_continues: bool = _same_vertical_bank(island, edge_x, row - 1, west_land, east_land)
			var next_continues: bool = _same_vertical_bank(island, edge_x, row + 1, west_land, east_land)
			var wave: float = _coherent_seam_wave(along, point.z, seed_phase, prev_continues, next_continues)
			var taper: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, absf(point.x - float(edge_x) * tile))
			var offset: float = (0.26 + 0.17 * absf(sin(point.z * 0.82 + seed_phase))) * wave * taper * strength
			displacement.x += offset if east_land else -offset
	if edge_z > 0 and edge_z < island.depth and column >= 0 and column < island.width:
		var north_land: bool = island.is_land(column, edge_z - 1)
		var south_land: bool = island.is_land(column, edge_z)
		if north_land != south_land:
			var along: float = clampf(point.x / tile - float(column), 0.0, 1.0)
			var prev_continues: bool = _same_horizontal_bank(island, edge_z, column - 1, north_land, south_land)
			var next_continues: bool = _same_horizontal_bank(island, edge_z, column + 1, north_land, south_land)
			var wave: float = _coherent_seam_wave(along, point.x, -seed_phase, prev_continues, next_continues)
			var taper: float = 1.0 - smoothstep(0.0, EDGE_INFLUENCE, absf(point.z - float(edge_z) * tile))
			var offset: float = (0.26 + 0.17 * absf(sin(point.x * 0.91 - seed_phase))) * wave * taper * strength
			displacement.z += offset if south_land else -offset
	return displacement


static func _same_vertical_bank(island: IslandDefinition, edge_x: int, row: int, west_land: bool, east_land: bool) -> bool:
	return row >= 0 and row < island.depth and island.is_land(edge_x - 1, row) == west_land and island.is_land(edge_x, row) == east_land


static func _same_horizontal_bank(island: IslandDefinition, edge_z: int, column: int, north_land: bool, south_land: bool) -> bool:
	return column >= 0 and column < island.width and island.is_land(column, edge_z - 1) == north_land and island.is_land(column, edge_z) == south_land


static func _coherent_seam_wave(along: float, world_along: float, phase: float, before: bool, after: bool) -> float:
	# Sprint 39: C1-like joins where consecutive edges have identical land/sea
	# orientation. The old sin(PI*t) always returned zero at EVERY tile seam,
	# making coastline noise visibly repeat at grid-cell boundaries.
	var local_hump: float = pow(sin(PI * along), 2.0)
	var continuity: float = lerpf(1.0 if before else 0.0, 1.0 if after else 0.0, smoothstep(0.0, 1.0, along))
	var long_wave: float = 0.72 * sin(world_along * 0.51 + phase) + 0.28 * sin(world_along * 1.09 - phase * 0.73)
	return (0.40 + 0.19 * sin(world_along * 0.37 + phase)) * local_hump + 0.60 * continuity * long_wave


static func boundary_at(island: IslandDefinition, side: int, along_world: float) -> float:
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	match side:
		0:
			return warp_ground(island, Vector3(0.0, 0.0, clampf(along_world, 0.0, d)), 0).x
		1:
			return warp_ground(island, Vector3(w, 0.0, clampf(along_world, 0.0, d)), 0).x
		2:
			return warp_ground(island, Vector3(clampf(along_world, 0.0, w), 0.0, 0.0), 0).z
		_:
			return warp_ground(island, Vector3(clampf(along_world, 0.0, w), 0.0, d), 0).z


static func distance_to_coast(island: IslandDefinition, x: float, z: float) -> float:
	# Sand is now measured to the SAME warped skirt/arc geometry as the actual
	# beach renderer. Previously it used square missing-cell bounding boxes,
	# producing a visibly grid-shaped sand band around an organic coastline.
	var tile: float = IslandDefinition.TILE_SIZE
	var w: float = float(island.width) * tile
	var d: float = float(island.depth) * tile
	var nearest: float = minf(minf(x, w - x), minf(z, d - z))
	# Outermost coastal sculpt can move the boundary by ~1.6 units; far
	# interior vertices need not recompute four expensive boundary warps.
	if nearest < 5.0:
		nearest = minf(minf(absf(x - boundary_at(island, 0, z)), absf(x - boundary_at(island, 1, z))),
			minf(absf(z - boundary_at(island, 2, x)), absf(z - boundary_at(island, 3, x))))
	if _shore_cache_instance != island.get_instance_id() or _shore_cache_revision != island.coastline_revision:
		prepare_shoreline_cache(island)
	if not _shore_cache_has_holes:
		return nearest
	var key := Vector2i(floori(x / tile), floori(z / tile))
	var segments: Array = _shore_segments_by_bin.get(key, [])
	var point := Vector2(x, z)
	var nearest_squared: float = nearest * nearest
	for index in range(0, segments.size(), 2):
		nearest_squared = minf(nearest_squared, _point_to_segment_squared(point, segments[index], segments[index + 1]))
	return sqrt(nearest_squared)


static func on_island(island: IslandDefinition, x: float, z: float) -> bool:
	# Movement cannot wander across a cove that has no supporting ground mesh.
	# Cliff/river collision still performs the authoritative vertical test.
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	if x < -OUTER_WARP_GUARD or z < -OUTER_WARP_GUARD or x > w + OUTER_WARP_GUARD or z > d + OUTER_WARP_GUARD:
		return false
	var tile: float = IslandDefinition.TILE_SIZE
	# Clamp ONLY the logical mask lookup. Use the original, unclamped world
	# coordinates for analytic edges below. Previously the unconditional
	# x<0/x>=w early return cut off valid warped beach triangles, leaving
	# a thin collision/SDF disagreement along outward-facing coasts.
	var cell_x: int = clampi(floori(x / tile), 0, island.width - 1)
	var cell_z: int = clampi(floori(z / tile), 0, island.depth - 1)
	if not island.is_land(cell_x, cell_z):
		# These tiny patches are actual ground triangles in TerrainBuilder and
		# use its WorldCollision. The SDF and traversal must agree with them.
		for corner in range(4):
			if TerrainBuilder.on_concave_fillet(island, cell_x, cell_z, corner, Vector2(x, z)):
				return true
		return false
	if x < 0.0 or z < 0.0 or x >= w or z >= d:
		# Clamp only each boundary's along-parameter. At a displaced corner,
		# both outer-axis inequalities still need to hold simultaneously.
		var along_z: float = clampf(z, 0.0, d)
		var along_x: float = clampf(x, 0.0, w)
		return (x >= boundary_at(island, 0, along_z) - 0.015
			and x <= boundary_at(island, 1, along_z) + 0.015
			and z >= boundary_at(island, 2, along_x) - 0.015
			and z <= boundary_at(island, 3, along_x) + 0.015)
	# Convex topological corners use the same shared rounding envelope as
	# TerrainBuilder. Gameplay must not walk across a visually cut-off corner.
	for corner in range(4):
		var north_side: bool = corner == 0 or corner == 1
		var west_side: bool = corner == 0 or corner == 3
		var nz: int = cell_z - 1 if north_side else cell_z + 1
		var nx: int = cell_x - 1 if west_side else cell_x + 1
		if island.contains(cell_x, nz) and island.contains(nx, cell_z) and not island.is_land(cell_x, nz) and not island.is_land(nx, cell_z):
			var radius: float = TerrainBuilder.MASK_CORNER_RADIUS
			var center_x: float = float(cell_x) * tile + (radius if west_side else tile - radius)
			var center_z: float = float(cell_z) * tile + (radius if north_side else tile - radius)
			var corner_region: bool = (x < center_x if west_side else x > center_x) and (z < center_z if north_side else z > center_z)
			if corner_region and Vector2(x - center_x, z - center_z).length() > radius + 0.013:
				return false
	# A hole's coastal mesh is inset *within* the surviving tile. Keep the
	# analytic movement gate inside the actual triangulated ground silhouette.
	if not island.is_land(cell_x - 1, cell_z) and cell_x > 0:
		if x < warp_ground(island, Vector3(float(cell_x) * tile, 0.0, z), 0).x - 0.015:
			return false
	if not island.is_land(cell_x + 1, cell_z) and cell_x < island.width - 1:
		if x > warp_ground(island, Vector3(float(cell_x + 1) * tile, 0.0, z), 0).x + 0.015:
			return false
	if not island.is_land(cell_x, cell_z - 1) and cell_z > 0:
		if z < warp_ground(island, Vector3(x, 0.0, float(cell_z) * tile), 0).z - 0.015:
			return false
	if not island.is_land(cell_x, cell_z + 1) and cell_z < island.depth - 1:
		if z > warp_ground(island, Vector3(x, 0.0, float(cell_z + 1) * tile), 0).z + 0.015:
			return false
	if x > EDGE_INFLUENCE and x < w - EDGE_INFLUENCE and z > EDGE_INFLUENCE and z < d - EDGE_INFLUENCE:
		return true
	var west: float = boundary_at(island, 0, z)
	var east: float = boundary_at(island, 1, z)
	var north: float = boundary_at(island, 2, x)
	var south: float = boundary_at(island, 3, x)
	return x >= west - 0.015 and x <= east + 0.015 and z >= north - 0.015 and z <= south + 0.015
