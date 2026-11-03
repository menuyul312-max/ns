class_name RiverContour
extends RefCounted
## Global continuous water field. No per-tile perimeter meshes: triangles are
## clipped against one shared scalar field, so adjacent cells share contours.

const SAMPLES_PER_TILE: int = 12
const THRESHOLD: float = 0.5
const BANK_WIDTH: float = 0.19
const EPSILON: float = 0.06

var island: IslandDefinition
var distances: PackedInt32Array
var flow_dirs: Array[Vector2]


func _init(source: IslandDefinition) -> void:
	island = source
	_build_flow()


static func field_at(source: IslandDefinition, world_x: float, world_z: float, level: int) -> float:
	var unit: float = IslandDefinition.TILE_SIZE
	# Smooth world-space domain warp bends long straight river banks coherently.
	# No per-tile randomness: terrain, depth, water mesh and traversal use one field.
	var phase: float = float(source.seed % 137) * 0.017
	var bend_x: float = 0.155 * sin(world_z * 0.47 + phase) + 0.061 * sin(world_z * 1.31 - phase * 0.67)
	var bend_z: float = 0.137 * sin(world_x * 0.49 - phase * 1.13) + 0.054 * sin(world_x * 1.39 + phase * 0.42)
	var warped_x: float = world_x + bend_x
	var warped_z: float = world_z + bend_z
	var gx: float = warped_x / unit - 0.5
	var gz: float = warped_z / unit - 0.5
	var ix: int = floori(gx)
	var iz: int = floori(gz)
	var fx: float = smoothstep(0.0, 1.0, gx - float(ix))
	var fz: float = smoothstep(0.0, 1.0, gz - float(iz))
	var a: float = _occupancy(source, ix, iz, level)
	var b: float = _occupancy(source, ix + 1, iz, level)
	var c: float = _occupancy(source, ix + 1, iz + 1, level)
	var d: float = _occupancy(source, ix, iz + 1, level)
	var interpolated: float = lerpf(lerpf(a, b, fx), lerpf(d, c, fx), fz)
	var variation: float = 0.034 * sin(warped_x * 1.27 + phase * 1.7) + 0.025 * sin(warped_z * 1.51 - phase)
	return clampf(interpolated + variation * 4.0 * interpolated * (1.0 - interpolated), 0.0, 1.0)


static func _occupancy(source: IslandDefinition, x: int, z: int, level: int) -> float:
	if source.contains(x, z):
		if not source.is_land(x, z):
			if level == 0:
				for neighbor in [Vector2i(x - 1, z), Vector2i(x + 1, z), Vector2i(x, z - 1), Vector2i(x, z + 1)]:
					if source.is_water(neighbor.x, neighbor.y) and source.height_at(neighbor.x, neighbor.y) == 0:
						return 0.65
			return 0.0
		return 1.0 if source.is_water(x, z) and source.height_at(x, z) == level else 0.0
	# A level-0 river on the map boundary connects to the sea instead of
	# collapsing into a rounded dead end one half-cell before the coast.
	if level == 0 and x >= -1 and x <= source.width and z >= -1 and z <= source.depth:
		var cx: int = clampi(x, 0, source.width - 1)
		var cz: int = clampi(z, 0, source.depth - 1)
		return 1.0 if source.is_water(cx, cz) and source.height_at(cx, cz) == 0 else 0.0
	return 0.0


func contains_water(world_position: Vector3) -> bool:
	for level in wet_levels():
		var water_y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND
		if absf(world_position.y - water_y) <= 0.25 and field_at(island, world_position.x, world_position.z, level) >= THRESHOLD:
			return true
	return false


func wet_levels() -> Array[int]:
	var levels: Array[int] = []
	for z in range(island.depth):
		for x in range(island.width):
			if island.is_water(x, z):
				var level: int = island.height_at(x, z)
				if not levels.has(level):
					levels.append(level)
	levels.sort()
	return levels


func append_mesh(water_tool: SurfaceTool, bank_tool: SurfaceTool, foam_tool: SurfaceTool) -> Dictionary:
	var surface_triangles: int = 0
	var bank_segments: int = 0
	var foam_segments: int = 0
	var unit: float = IslandDefinition.TILE_SIZE
	var step: float = unit / float(SAMPLES_PER_TILE)
	for level in wet_levels():
		var surface_y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND
		for gz in range(island.depth * SAMPLES_PER_TILE):
			for gx in range(island.width * SAMPLES_PER_TILE):
				var x0: float = float(gx) * step
				var z0: float = float(gz) * step
				var p: Array[Vector2] = [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
				var f: Array[float] = [field_at(island, p[0].x, p[0].y, level), field_at(island, p[1].x, p[1].y, level), field_at(island, p[2].x, p[2].y, level), field_at(island, p[3].x, p[3].y, level)]
				if maxf(maxf(f[0], f[1]), maxf(f[2], f[3])) < THRESHOLD:
					continue
				for triangle in [[0, 1, 2], [0, 2, 3]]:
					var contour: Dictionary = _clip_triangle([p[triangle[0]], p[triangle[1]], p[triangle[2]]], [f[triangle[0]], f[triangle[1]], f[triangle[2]]])
					var polygon: Array[Vector2] = contour["polygon"]
					if polygon.size() >= 3:
						for index in range(1, polygon.size() - 1):
							_emit_water_triangle(water_tool, polygon[0], polygon[index], polygon[index + 1], surface_y)
							surface_triangles += 1
					var crossings: Array[Vector2] = contour["crossings"]
					if crossings.size() == 2 and crossings[0].distance_to(crossings[1]) > 0.0001:
						if not _near_waterfall_crossing(crossings[0].lerp(crossings[1], 0.5), level) and CoastContour.on_island(island, crossings[0].lerp(crossings[1], 0.5).x, crossings[0].lerp(crossings[1], 0.5).y):
							bank_segments += 1
							foam_segments += _emit_bank_and_foam(bank_tool, foam_tool, crossings[0], crossings[1], level)
	return {"water_triangles": surface_triangles, "bank_segments": bank_segments, "foam_segments": foam_segments}


static func _clip_triangle(points: Array[Vector2], values: Array[float]) -> Dictionary:
	var inside: Array[Vector2] = []
	var crossings: Array[Vector2] = []
	for i in range(3):
		var j: int = (i + 1) % 3
		var a: Vector2 = points[i]
		var b: Vector2 = points[j]
		var fa: float = values[i]
		var fb: float = values[j]
		var is_inside_a: bool = fa >= THRESHOLD
		var is_inside_b: bool = fb >= THRESHOLD
		if is_inside_a:
			inside.append(a)
		if is_inside_a != is_inside_b:
			var t: float = (THRESHOLD - fa) / (fb - fa)
			var intersection: Vector2 = a.lerp(b, t)
			inside.append(intersection)
			crossings.append(intersection)
	return {"polygon": inside, "crossings": crossings}


func _emit_water_triangle(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float) -> void:
	for p in [a, b, c]:
		var flow: Vector2 = flow_at(p)
		var alpha: float = 1.0
		if is_equal_approx(y, WaterBuilder.WATER_ABOVE_GROUND):
			var edge_distance: float = minf(minf(p.x, float(island.width) * IslandDefinition.TILE_SIZE - p.x),
				minf(p.y, float(island.depth) * IslandDefinition.TILE_SIZE - p.y))
			if island.land_mask.count(0) > 0:
				var tile: float = IslandDefinition.TILE_SIZE
				var center_x: int = floori(p.x / tile)
				var center_z: int = floori(p.y / tile)
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx: int = center_x + dx
						var nz: int = center_z + dz
						if island.contains(nx, nz) and not island.is_land(nx, nz):
							var closest_x: float = clampf(p.x, float(nx) * tile, float(nx + 1) * tile)
							var closest_z: float = clampf(p.y, float(nz) * tile, float(nz + 1) * tile)
							edge_distance = minf(edge_distance, Vector2(p.x - closest_x, p.y - closest_z).length())
			alpha = 0.12 + 0.88 * smoothstep(0.0, 1.35, edge_distance)
		tool.set_color(Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, 1.0, alpha))
		tool.set_uv(p * 0.22)
		tool.add_vertex(Vector3(p.x, y, p.y))


func _emit_bank_and_foam(bank_tool: SurfaceTool, foam_tool: SurfaceTool, a: Vector2, b: Vector2, level: int) -> int:
	var center: Vector2 = (a + b) * 0.5
	var grad := Vector2(
		field_at(island, center.x + EPSILON, center.y, level) - field_at(island, center.x - EPSILON, center.y, level),
		field_at(island, center.x, center.y + EPSILON, level) - field_at(island, center.x, center.y - EPSILON, level)
	)
	if grad.length_squared() < 0.0000001:
		var tangent: Vector2 = (b - a).normalized()
		grad = Vector2(-tangent.y, tangent.x)
		if field_at(island, center.x + grad.x * 0.1, center.y + grad.y * 0.1, level) < field_at(island, center.x - grad.x * 0.1, center.y - grad.y * 0.1, level):
			grad = -grad
	grad = grad.normalized()
	var y: float = float(level) * IslandDefinition.HEIGHT_STEP
	var inner_a := Vector3(a.x, y + WaterBuilder.WATER_ABOVE_GROUND - 0.008, a.y)
	var inner_b := Vector3(b.x, y + WaterBuilder.WATER_ABOVE_GROUND - 0.008, b.y)
	var outer_a := Vector3(a.x - grad.x * BANK_WIDTH, y + 0.018, a.y - grad.y * BANK_WIDTH)
	var outer_b := Vector3(b.x - grad.x * BANK_WIDTH, y + 0.018, b.y - grad.y * BANK_WIDTH)
	# The wet edge fades into local land color instead of making a uniform yellow
	# ribbon. The same strip remains the physical collision surface.
	var land_probe := Vector3(center.x - grad.x * BANK_WIDTH, y, center.y - grad.y * BANK_WIDTH)
	var dry_color: Color = TerrainBuilder._ground_color(island, level, land_probe)
	var wet_color: Color = dry_color.darkened(0.27)
	_emit_gradient_up_quad(bank_tool, inner_a, inner_b, outer_b, outer_a, wet_color, dry_color)
	# A continuous but extremely broken wash: transparency fades inward and the
	# shader modulates it with animated world-space flecks. No rectangular decals.
	var patch_signal: float = 0.5 + 0.25 * sin(center.x * 1.73 + center.y * 0.91) + 0.25 * sin(center.y * 1.57 - center.x * 0.58)
	var strength: float = 0.14 + 0.57 * smoothstep(0.48, 0.94, patch_signal)
	var near_a := Vector3(a.x + grad.x * 0.013, y + WaterBuilder.WATER_ABOVE_GROUND + 0.018, a.y + grad.y * 0.013)
	var near_b := Vector3(b.x + grad.x * 0.013, y + WaterBuilder.WATER_ABOVE_GROUND + 0.018, b.y + grad.y * 0.013)
	var deep_a := Vector3(a.x + grad.x * 0.117, y + WaterBuilder.WATER_ABOVE_GROUND + 0.018, a.y + grad.y * 0.117)
	var deep_b := Vector3(b.x + grad.x * 0.117, y + WaterBuilder.WATER_ABOVE_GROUND + 0.018, b.y + grad.y * 0.117)
	_emit_gradient_up_quad(foam_tool, near_a, near_b, deep_b, deep_a,
		Color(0.86, 0.97, 0.99, strength), Color(0.86, 0.97, 0.99, 0.0))
	return 1


static func _emit_up_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).y < 0.0:
		WaterBuilder._emit_quad(tool, b, a, d, c, color)
	else:
		WaterBuilder._emit_quad(tool, a, b, c, d, color)


static func _emit_gradient_up_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, near: Color, far: Color) -> void:
	if (b - a).cross(c - a).y < 0.0:
		_emit_gradient_triangle(tool, b, a, d, near, near, far)
		_emit_gradient_triangle(tool, b, d, c, near, far, far)
	else:
		_emit_gradient_triangle(tool, a, b, c, near, near, far)
		_emit_gradient_triangle(tool, a, c, d, near, far, far)


static func _emit_gradient_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for vertex in [[a, ca], [c, cc], [b, cb]]:
		var p: Vector3 = vertex[0]
		tool.set_color(vertex[1])
		tool.set_uv(Vector2(p.x, p.z) * 0.22)
		tool.add_vertex(p)


func _near_waterfall_crossing(point: Vector2, level: int) -> bool:
	var radius: float = IslandDefinition.TILE_SIZE * 0.52
	for direction in [Vector2(-radius, 0), Vector2(radius, 0), Vector2(0, -radius), Vector2(0, radius)]:
		var sample: Vector2 = point + direction
		var x: int = floori(sample.x / IslandDefinition.TILE_SIZE)
		var z: int = floori(sample.y / IslandDefinition.TILE_SIZE)
		if island.is_water(x, z) and island.height_at(x, z) != level:
			return true
	return false


func flow_at(world_position: Vector2) -> Vector2:
	var gx: float = world_position.x / IslandDefinition.TILE_SIZE - 0.5
	var gz: float = world_position.y / IslandDefinition.TILE_SIZE - 0.5
	var ix: int = floori(gx)
	var iz: int = floori(gz)
	var fx: float = smoothstep(0.0, 1.0, gx - float(ix))
	var fz: float = smoothstep(0.0, 1.0, gz - float(iz))
	var interpolated: Vector2 = Vector2.ZERO
	for dz in range(2):
		for dx in range(2):
			var x: int = ix + dx
			var z: int = iz + dz
			if island.contains(x, z):
				var weight: float = (fx if dx == 1 else 1.0 - fx) * (fz if dz == 1 else 1.0 - fz)
				interpolated += flow_dirs[z * island.width + x] * weight
	return interpolated.normalized() if interpolated.length_squared() > 0.0001 else Vector2.ZERO


func _build_flow() -> void:
	var count: int = island.width * island.depth
	distances.resize(count)
	distances.fill(-1)
	flow_dirs.resize(count)
	for i in range(count):
		flow_dirs[i] = Vector2.ZERO
	var outlet := Vector2i(-1, -1)
	var min_level: int = 999
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			var level: int = island.height_at(x, z)
			if level < min_level or (level == min_level and (z > outlet.y or (z == outlet.y and x > outlet.x))):
				min_level = level
				outlet = Vector2i(x, z)
	if outlet.x < 0:
		return
	var queue: Array[Vector2i] = [outlet]
	distances[outlet.y * island.width + outlet.x] = 0
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_distance: int = distances[current.y * island.width + current.x]
		for adjacent in [Vector2i(current.x - 1, current.y), Vector2i(current.x + 1, current.y), Vector2i(current.x, current.y - 1), Vector2i(current.x, current.y + 1)]:
			if not island.is_water(adjacent.x, adjacent.y):
				continue
			var index: int = adjacent.y * island.width + adjacent.x
			if distances[index] == -1:
				distances[index] = current_distance + 1
				queue.append(adjacent)
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			var index: int = z * island.width + x
			var distance: int = distances[index]
			var best := Vector2.ZERO
			var current_level: int = island.height_at(x, z)
			for adjacent in [Vector2i(x - 1, z), Vector2i(x + 1, z), Vector2i(x, z - 1), Vector2i(x, z + 1)]:
				if island.is_water(adjacent.x, adjacent.y) and island.height_at(adjacent.x, adjacent.y) <= current_level:
					var next_distance: int = distances[adjacent.y * island.width + adjacent.x]
					if next_distance >= 0 and next_distance < distance:
						distance = next_distance
						best = Vector2(float(adjacent.x - x), float(adjacent.y - z))
			flow_dirs[index] = best
