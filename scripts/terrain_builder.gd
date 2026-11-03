class_name TerrainBuilder
extends RefCounted
## Synthetic, original mesh builder. Not a port of ACNH mesh algorithms.

const EDGE_SUBDIVISIONS: int = 10
const CORNER_SUBDIVISIONS: int = 10
const WALL_ROWS: int = 8
const CORNER_RADIUS: float = 0.43
const MASK_CORNER_RADIUS: float = 0.82
const INLET_FILLET_RADIUS: float = 0.72
const CORNER_ARC_MIX: float = 0.62
const GROUND_RADIAL_ROWS: int = 6

const GROUND_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 world_point;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float meadow = noise21(world_point.xz * 0.88);
	float fine = noise21(world_point.xz * 3.8 + vec2(2.3, 7.1));
	float speckle = smoothstep(0.78, 0.93, noise21(world_point.xz * 12.5));
	ALBEDO = COLOR.rgb * (0.79 + 0.20 * meadow + 0.10 * fine)
		+ vec3(0.005, 0.016, 0.002) * speckle;
	ROUGHNESS = 0.93;
}
"""

const CLIFF_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 world_point;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 stone = vec2(world_point.x + world_point.z * 0.73, world_point.y);
	float ochre = noise21(stone * vec2(3.2, 4.6));
	float vein = noise21(stone * vec2(9.1, 2.5) + vec2(4.9, 1.1));
	float strata = smoothstep(0.52, 0.83, sin(stone.y * 8.6 + ochre * 2.3) * 0.5 + 0.5);
	ALBEDO = COLOR.rgb * (0.79 + 0.25 * ochre + 0.12 * vein - 0.11 * strata);
	ROUGHNESS = 0.96;
}
"""


static func build_world(island: IslandDefinition) -> Node3D:
	# Keep the grass/sand color boundary synchronized with the exact shoreline
	# skirt and cove fillet segments before emitting any ground vertices.
	CoastContour.prepare_shoreline_cache(island)
	var root := Node3D.new()
	root.name = "Terrain_%dx%d" % [island.width, island.depth]
	var ground_tool := _new_tool()
	var wall_tool := _new_tool()
	var lip_tool := _new_tool()
	var detail_tool := _new_tool()
	var shore_skirt_tool := _new_tool()
	var detail_count: int = 0
	var shore_skirt_count: int = 0
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_land(x, z):
				continue
			var level: int = island.height_at(x, z)
			var neighbors := [
				island.height_at(x, z - 1),
				island.height_at(x + 1, z),
				island.height_at(x, z + 1),
				island.height_at(x - 1, z)
			]
			var rounded := _rounded_corners(level, neighbors)
			if level == 0:
				for corner in range(4):
					if _is_mask_corner(island, x, z, corner):
						rounded[corner] = true
			_add_ground(ground_tool, island, x, z, rounded)
			if not island.is_water(x, z) and int(island.terrain_layer_at(x, z, 1)["unit"]) != 0:
				_add_ground_detail(detail_tool, island, x, z)
				detail_count += 1
			if level == 0:
				for direction in range(4):
					var adjacent: Vector2i = Vector2i(x, z - 1) if direction == 0 else (Vector2i(x + 1, z) if direction == 1 else (Vector2i(x, z + 1) if direction == 2 else Vector2i(x - 1, z)))
					if island.contains(adjacent.x, adjacent.y) and not island.is_land(adjacent.x, adjacent.y):
						_add_shore_skirt(shore_skirt_tool, island, x, z, direction, rounded)
						shore_skirt_count += 1
				for corner in range(4):
					if _is_mask_corner(island, x, z, corner):
						_add_shore_corner_skirt(shore_skirt_tool, island, x, z, corner)
				continue
			for direction in range(4):
				if neighbors[direction] < level:
					if IslandLinkRules.ramp_opens_cliff(island, x, z, direction):
						# Retain narrow side cheeks to avoid a full-tile hole in the cliff.
						var side_margin: float = (1.0 - IslandLinkBuilder.DECK_WIDTH / IslandDefinition.TILE_SIZE) * 0.5
						_add_wall_and_lip(wall_tool, lip_tool, island, x, z, direction, level, neighbors[direction], rounded, 0.0, side_margin)
						_add_wall_and_lip(wall_tool, lip_tool, island, x, z, direction, level, neighbors[direction], rounded, 1.0 - side_margin, 1.0)
					else:
						_add_wall_and_lip(wall_tool, lip_tool, island, x, z, direction, level, neighbors[direction], rounded)
			for corner in range(4):
				if rounded[corner]:
					_add_rounded_corner(wall_tool, lip_tool, island, x, z, corner, level, neighbors[corner])
	# A missing cell surrounded by three low, dry land cells has a 90-degree
	# *reentrant* corner. Bridge its tiny corner pocket with a curved, collidable
	# sandy patch; the rest of the missing tile remains open sea. This pass uses
	# the SAME ground_tool that supplies WorldCollision (no visual-only collider).
	for z in range(island.depth):
		for x in range(island.width):
			if island.is_land(x, z):
				continue
			for corner in range(4):
				if _is_concave_mask_corner(island, x, z, corner):
					_add_concave_shore_fillet(ground_tool, shore_skirt_tool, island, x, z, corner)
					shore_skirt_count += 1
	ground_tool.generate_normals()
	wall_tool.generate_normals()
	lip_tool.generate_normals()
	var ground_mesh: ArrayMesh = ground_tool.commit()
	var cliff_mesh: ArrayMesh = wall_tool.commit()
	var lip_mesh: ArrayMesh = lip_tool.commit()
	_add_render_mesh(root, "Ground", ground_mesh, Color(0.95, 0.95, 0.95))
	_add_render_mesh(root, "CliffFaces", cliff_mesh, Color(0.94, 0.95, 0.95))
	_add_render_mesh(root, "GrassLips", lip_mesh, Color(1.0, 1.0, 1.0))
	if detail_count > 0:
		detail_tool.generate_normals()
		_add_render_mesh(root, "GroundDecorLayer", detail_tool.commit(), Color.WHITE)
	if shore_skirt_count > 0:
		shore_skirt_tool.generate_normals()
		_add_render_mesh(root, "MaskedShoreSkirts", shore_skirt_tool.commit(), Color.WHITE)
	var static_body := StaticBody3D.new()
	static_body.name = "WorldCollision"
	root.add_child(static_body)
	for collision_mesh in [ground_mesh, cliff_mesh]:
		if collision_mesh != null:
			var collision := CollisionShape3D.new()
			collision.shape = collision_mesh.create_trimesh_shape()
			static_body.add_child(collision)
	var features := Node3D.new()
	features.name = "TileOccupants"
	root.add_child(features)
	for z in range(island.depth):
		for x in range(island.width):
			var kind: int = island.occupant_at(x, z)
			if kind != 0 and not island.is_water(x, z):
				features.add_child(_make_occupant(island, x, z, kind))
	return root


static func _make_occupant(island: IslandDefinition, x: int, z: int, kind: int) -> StaticBody3D:
	var feature := StaticBody3D.new()
	feature.name = ("Tree" if kind == 1 else "RumahPanggung") + "_%d_%d" % [x, z]
	# Separate selection mask: edit-ray ignores silhouettes, while actor hits them.
	feature.collision_layer = 16
	feature.collision_mask = 0
	var px: float = (float(x) + 0.5) * IslandDefinition.TILE_SIZE
	var pz: float = (float(z) + 0.5) * IslandDefinition.TILE_SIZE
	feature.position = Vector3(px, RiverBathymetry.floor_height_at(island, px, pz, island.height_at(x, z)), pz)
	var collision := CollisionShape3D.new()
	collision.name = "FeatureCollision"
	if kind == 1:
		_add_primitive(feature, "Batang", _cylinder(0.13, 0.16, 1.18), Color(0.43, 0.26, 0.13), Vector3(0, 0.59, 0))
		for index in range(3):
			var crown := SphereMesh.new()
			crown.radius = 0.61 - float(index) * 0.10
			crown.height = 0.79
			var leaf_color := Color(0.17, 0.44, 0.25) if index % 2 == 0 else Color(0.23, 0.53, 0.24)
			_add_primitive(feature, "Daun%d" % index, crown, leaf_color, Vector3((float(index) - 1.0) * 0.21, 1.40 + float(index) * 0.25, 0))
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.25
		trunk_shape.height = 1.90
		collision.shape = trunk_shape
		collision.position.y = 0.95
	else:
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = Vector3(1.45, 0.18, 1.35)
		_add_primitive(feature, "Lantai", floor_mesh, Color(0.56, 0.34, 0.19), Vector3(0, 0.52, 0))
		for dx in [-0.54, 0.54]:
			for dz in [-0.49, 0.49]:
				_add_primitive(feature, "Tiang", _cylinder(0.07, 0.07, 1.20), Color(0.43, 0.23, 0.13), Vector3(dx, 0.71, dz))
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = 1.00
		roof.height = 0.61
		roof.radial_segments = 4
		_add_primitive(feature, "AtapLimas", roof, Color(0.68, 0.29, 0.17), Vector3(0, 1.54, 0), Vector3(0, PI / 4.0, 0))
		var building_shape := BoxShape3D.new()
		building_shape.size = Vector3(1.45, 1.75, 1.45)
		collision.shape = building_shape
		collision.position.y = 0.89
	feature.add_child(collision)
	return feature


static func _cylinder(top_radius: float, bottom_radius: float, cylinder_height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = cylinder_height
	return mesh


static func _add_primitive(parent: Node3D, label: String, mesh: Mesh, color: Color, offset: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = offset
	instance.rotation = rotation
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	instance.material_override = material
	parent.add_child(instance)


static func _new_tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add_render_mesh(root: Node3D, item_name: String, generated_mesh: Mesh, tint: Color) -> void:
	if generated_mesh == null:
		return
	var item := MeshInstance3D.new()
	item.name = item_name
	item.mesh = generated_mesh
	if item_name in ["Ground", "GrassLips", "CliffFaces"]:
		var shader := Shader.new()
		shader.code = CLIFF_SHADER if item_name == "CliffFaces" else GROUND_SHADER
		var stylized_material := ShaderMaterial.new()
		stylized_material.shader = shader
		item.material_override = stylized_material
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(item)


static func _rounded_corners(level: int, neighbors: Array) -> Array[bool]:
	var rounded: Array[bool] = [false, false, false, false]
	for corner in range(4):
		var preceding: int = (corner + 3) % 4
		# Do not bevel meeting walls with different bottom elevations yet.
		rounded[corner] = neighbors[preceding] < level and neighbors[corner] < level and neighbors[preceding] == neighbors[corner]
	return rounded


static func _add_ground(tool: SurfaceTool, island: IslandDefinition, x: int, z: int, rounded: Array[bool]) -> void:
	var size: float = IslandDefinition.TILE_SIZE
	var level: int = island.height_at(x, z)
	var top: float = float(level) * IslandDefinition.HEIGHT_STEP
	var center := Vector3((float(x) + 0.5) * size, top, (float(z) + 0.5) * size)
	var contour: Array[Vector3] = []
	for direction in range(4):
		var radius_start: float = MASK_CORNER_RADIUS if level == 0 and _is_mask_corner(island, x, z, direction) else CORNER_RADIUS
		var radius_end: float = MASK_CORNER_RADIUS if level == 0 and _is_mask_corner(island, x, z, (direction + 1) % 4) else CORNER_RADIUS
		var start_t: float = radius_start / size if rounded[direction] else 0.0
		var end_t: float = (1.0 - radius_end / size) if rounded[(direction + 1) % 4] else 1.0
		for segment in range(EDGE_SUBDIVISIONS):
			var t: float = lerpf(start_t, end_t, float(segment) / float(EDGE_SUBDIVISIONS))
			contour.append(_edge_position(x, z, direction, t, 0.0, top))
		if rounded[(direction + 1) % 4]:
			for segment in range(CORNER_SUBDIVISIONS):
				contour.append(_corner_arc_position(x, z, (direction + 1) % 4, float(segment) / float(CORNER_SUBDIVISIONS), 0.0, top, radius_end))
	for i in range(contour.size()):
		var edge_a: Vector3 = contour[i]
		var edge_b: Vector3 = contour[(i + 1) % contour.size()]
		for row in range(GROUND_RADIAL_ROWS):
			var start: float = float(row) / float(GROUND_RADIAL_ROWS)
			var finish: float = float(row + 1) / float(GROUND_RADIAL_ROWS)
			var inner_a: Vector3 = _ground_point(island, level, center.lerp(edge_a, start))
			var inner_b: Vector3 = _ground_point(island, level, center.lerp(edge_b, start))
			var outer_a: Vector3 = _ground_point(island, level, center.lerp(edge_a, finish))
			var outer_b: Vector3 = _ground_point(island, level, center.lerp(edge_b, finish))
			_emit_colored_triangle(tool, inner_a, outer_a, outer_b, _ground_color(island, level, inner_a), _ground_color(island, level, outer_a), _ground_color(island, level, outer_b))
			if row > 0:
				_emit_colored_triangle(tool, inner_a, outer_b, inner_b, _ground_color(island, level, inner_a), _ground_color(island, level, outer_b), _ground_color(island, level, inner_b))


static func _ground_point(island: IslandDefinition, level: int, point: Vector3) -> Vector3:
	point = CoastContour.warp_ground(island, point, level)
	point.y = RiverBathymetry.floor_height_at(island, point.x, point.z, level)
	return point


static func _add_shore_skirt(tool: SurfaceTool, island: IslandDefinition, x: int, z: int, direction: int, rounded: Array[bool]) -> void:
	# Stylized sandy thickness between a topological cove and the ocean sheet.
	var upper_color := Color(0.78, 0.70, 0.49)
	var lower_color := Color(0.37, 0.45, 0.42)
	var bounds: Vector2 = _shore_edge_bounds(island, x, z, direction, rounded)
	var start_t: float = bounds.x
	var end_t: float = bounds.y
	if end_t <= start_t:
		return
	for segment in range(EDGE_SUBDIVISIONS):
		var a: float = lerpf(start_t, end_t, float(segment) / float(EDGE_SUBDIVISIONS))
		var b: float = lerpf(start_t, end_t, float(segment + 1) / float(EDGE_SUBDIVISIONS))
		var top_a: Vector3 = _ground_point(island, 0, _edge_position(x, z, direction, a, 0.0, 0.0))
		var top_b: Vector3 = _ground_point(island, 0, _edge_position(x, z, direction, b, 0.0, 0.0))
		var low_a: Vector3 = top_a + Vector3(0.0, -0.31, 0.0)
		var low_b: Vector3 = top_b + Vector3(0.0, -0.31, 0.0)
		_emit_facet_quad(tool, top_a, top_b, low_b, low_a, upper_color, upper_color, lower_color, lower_color)


static func _shore_edge_bounds(island: IslandDefinition, x: int, z: int, direction: int, rounded: Array[bool]) -> Vector2:
	# Identical trim intervals for the actual 3D skirt and the cached shoreline
	# polyline used to color beach vertices. No second approximate silhouette.
	var start_t: float = MASK_CORNER_RADIUS / IslandDefinition.TILE_SIZE if rounded[direction] else 0.0
	var end_t: float = 1.0 - MASK_CORNER_RADIUS / IslandDefinition.TILE_SIZE if rounded[(direction + 1) % 4] else 1.0
	# A concave fillet covers the first/last radius of a raw mask edge. Trimming
	# the vertical skirt removes the old L-shaped line visible *through* the cap.
	if _concave_at_shore_endpoint(island, x, z, direction, 0.0):
		start_t = maxf(start_t, INLET_FILLET_RADIUS / IslandDefinition.TILE_SIZE)
	if _concave_at_shore_endpoint(island, x, z, direction, 1.0):
		end_t = minf(end_t, 1.0 - INLET_FILLET_RADIUS / IslandDefinition.TILE_SIZE)
	return Vector2(start_t, end_t)


static func _add_shore_corner_skirt(tool: SurfaceTool, island: IslandDefinition, x: int, z: int, corner: int) -> void:
	var upper_color := Color(0.78, 0.70, 0.49)
	var lower_color := Color(0.37, 0.45, 0.42)
	for segment in range(CORNER_SUBDIVISIONS):
		var a: float = float(segment) / float(CORNER_SUBDIVISIONS)
		var b: float = float(segment + 1) / float(CORNER_SUBDIVISIONS)
		var top_a: Vector3 = _ground_point(island, 0, _corner_arc_position(x, z, corner, a, 0.0, 0.0, MASK_CORNER_RADIUS))
		var top_b: Vector3 = _ground_point(island, 0, _corner_arc_position(x, z, corner, b, 0.0, 0.0, MASK_CORNER_RADIUS))
		_emit_facet_quad(tool, top_a, top_b, top_b + Vector3(0, -0.31, 0), top_a + Vector3(0, -0.31, 0), upper_color, upper_color, lower_color, lower_color)


static func _is_mask_corner(island: IslandDefinition, x: int, z: int, corner: int) -> bool:
	var a: Vector2i = Vector2i(x, z - 1) if corner in [0, 1] else Vector2i(x, z + 1)
	var b: Vector2i = Vector2i(x - 1, z) if corner in [0, 3] else Vector2i(x + 1, z)
	return island.contains(a.x, a.y) and island.contains(b.x, b.y) and not island.is_land(a.x, a.y) and not island.is_land(b.x, b.y)


static func _is_concave_mask_corner(island: IslandDefinition, x: int, z: int, corner: int) -> bool:
	if island.is_land(x, z) or not island.contains(x, z):
		return false
	var dx: int = -1 if corner in [0, 3] else 1
	var dz: int = -1 if corner in [0, 1] else 1
	# Require the two orthogonal supports AND the diagonal. A single-tile
	# channel or elevated/wet neighbor cannot be closed by smoothing.
	for cell in [Vector2i(x + dx, z), Vector2i(x, z + dz), Vector2i(x + dx, z + dz)]:
		if not island.is_land(cell.x, cell.y) or island.height_at(cell.x, cell.y) != 0 or island.is_water(cell.x, cell.y):
			return false
	return true


static func _concave_at_shore_endpoint(island: IslandDefinition, x: int, z: int, direction: int, t: float) -> bool:
	var sea: Vector2i = Vector2i(x, z - 1) if direction == 0 else (Vector2i(x + 1, z) if direction == 1 else (Vector2i(x, z + 1) if direction == 2 else Vector2i(x - 1, z)))
	if not island.contains(sea.x, sea.y) or island.is_land(sea.x, sea.y):
		return false
	var point: Vector3 = _edge_position(x, z, direction, t, 0.0, 0.0)
	var cx: float = point.x - float(sea.x) * IslandDefinition.TILE_SIZE
	var cz: float = point.z - float(sea.y) * IslandDefinition.TILE_SIZE
	var corner: int = 0 if cx < 0.5 * IslandDefinition.TILE_SIZE and cz < 0.5 * IslandDefinition.TILE_SIZE else (1 if cz < 0.5 * IslandDefinition.TILE_SIZE else (2 if cx > 0.5 * IslandDefinition.TILE_SIZE else 3))
	return _is_concave_mask_corner(island, sea.x, sea.y, corner)


static func _concave_arc_point(x: int, z: int, corner: int, t: float) -> Vector3:
	# The patch is the small corner pocket OUTSIDE a quarter-circle centred
	# IN the sea tile. Its arc is tangent to both adjacent shoreline segments.
	var radius: float = INLET_FILLET_RADIUS
	var dx: float = -1.0 if corner in [1, 2] else 1.0
	var dz: float = -1.0 if corner in [2, 3] else 1.0
	var corner_x: float = float(x) * IslandDefinition.TILE_SIZE + (0.0 if dx > 0.0 else IslandDefinition.TILE_SIZE)
	var corner_z: float = float(z) * IslandDefinition.TILE_SIZE + (0.0 if dz > 0.0 else IslandDefinition.TILE_SIZE)
	var angle: float = -PI * 0.5 - t * PI * 0.5
	return Vector3(corner_x + dx * (radius + radius * cos(angle)), 0.0,
		corner_z + dz * (radius + radius * sin(angle)))


static func _add_concave_shore_fillet(ground_tool: SurfaceTool, skirt_tool: SurfaceTool, island: IslandDefinition, x: int, z: int, corner: int) -> void:
	var dx: float = -1.0 if corner in [1, 2] else 1.0
	var dz: float = -1.0 if corner in [2, 3] else 1.0
	var origin := Vector3(float(x) * IslandDefinition.TILE_SIZE + (0.0 if dx > 0.0 else IslandDefinition.TILE_SIZE),
		0.0, float(z) * IslandDefinition.TILE_SIZE + (0.0 if dz > 0.0 else IslandDefinition.TILE_SIZE))
	origin = _ground_point(island, 0, origin)
	for segment in range(CORNER_SUBDIVISIONS):
		var a: float = float(segment) / float(CORNER_SUBDIVISIONS)
		var b: float = float(segment + 1) / float(CORNER_SUBDIVISIONS)
		var edge_a: Vector3 = _ground_point(island, 0, _concave_arc_point(x, z, corner, a))
		var edge_b: Vector3 = _ground_point(island, 0, _concave_arc_point(x, z, corner, b))
		if (edge_a - origin).cross(edge_b - origin).y > 0.0:
			var swap: Vector3 = edge_a
			edge_a = edge_b
			edge_b = swap
		_emit_colored_triangle(ground_tool, origin, edge_a, edge_b,
			_ground_color(island, 0, origin), _ground_color(island, 0, edge_a), _ground_color(island, 0, edge_b))
		_emit_facet_quad(skirt_tool, edge_a, edge_b,
			edge_b + Vector3(0, -0.31, 0), edge_a + Vector3(0, -0.31, 0),
			Color(0.78, 0.70, 0.49), Color(0.78, 0.70, 0.49), Color(0.37, 0.45, 0.42), Color(0.37, 0.45, 0.42))


static func on_concave_fillet(island: IslandDefinition, x: int, z: int, corner: int, point: Vector2) -> bool:
	# Reconstruct the actual triangles used for rendering/collision. Checking the
	# analytical unwarped circle would disagree wherever CoastContour warped it.
	if not _is_concave_mask_corner(island, x, z, corner):
		return false
	var dx: float = -1.0 if corner in [1, 2] else 1.0
	var dz: float = -1.0 if corner in [2, 3] else 1.0
	var origin: Vector3 = _ground_point(island, 0, Vector3(float(x) * IslandDefinition.TILE_SIZE + (0.0 if dx > 0.0 else IslandDefinition.TILE_SIZE), 0.0,
		float(z) * IslandDefinition.TILE_SIZE + (0.0 if dz > 0.0 else IslandDefinition.TILE_SIZE)))
	var a: Vector2 = Vector2(origin.x, origin.z)
	for segment in range(CORNER_SUBDIVISIONS):
		var first: Vector3 = _ground_point(island, 0, _concave_arc_point(x, z, corner, float(segment) / float(CORNER_SUBDIVISIONS)))
		var second: Vector3 = _ground_point(island, 0, _concave_arc_point(x, z, corner, float(segment + 1) / float(CORNER_SUBDIVISIONS)))
		if _inside_footprint_triangle(point, a, Vector2(first.x, first.z), Vector2(second.x, second.z)):
			return true
	return false


static func _inside_footprint_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d0: float = (b - a).cross(point - a)
	var d1: float = (c - b).cross(point - b)
	var d2: float = (a - c).cross(point - c)
	return (d0 >= -0.0001 and d1 >= -0.0001 and d2 >= -0.0001) or (d0 <= 0.0001 and d1 <= 0.0001 and d2 <= 0.0001)


static func _ground_color(island: IslandDefinition, level: int, position: Vector3) -> Color:
	# World-space vertex color removes the tile-by-tile checkerboard.
	var seed: float = float(island.seed % 311) * 0.013
	var broad: float = sin(position.x * 0.43 + seed) * sin(position.z * 0.53 - seed)
	var fine: float = sin(position.x * 1.23 + position.z * 0.82) * sin(position.z * 1.02 - position.x * 0.37)
	var variation: float = 0.022 * broad + 0.010 * fine
	# Level zero is *not* synonymous with beach. Keep an organic strip of sand
	# beside the outer coast while letting the entire island interior be grass.
	# This visual mask is independent of the authoritative logical height grid.
	var grass := Color(0.235 + variation * 0.68, 0.40 + variation, 0.18 + variation * 0.61)
	var sand := Color(0.65 + variation * 0.48, 0.555 + variation * 0.58, 0.385 + variation * 0.41)
	var dry: Color = grass
	if level == 0:
		var to_coast: float = CoastContour.distance_to_coast(island, position.x, position.z)
		var coast_offset: float = 0.20 * sin(position.x * 0.58 + seed) + 0.14 * sin(position.z * 0.89 - seed)
		var beach: float = 1.0 - smoothstep(1.06, 3.35, to_coast + coast_offset)
		dry = grass.lerp(sand, beach)
	var wet: float = smoothstep(0.21, 0.82, RiverContour.field_at(island, position.x, position.z, level))
	var result: Color = dry.lerp(Color(0.25 + variation, 0.38 + variation, 0.32 + variation), wet * 0.70)
	# Paint is blended from nearby cell CENTERS in world coordinates. Neighboring
	# footpath units join organically rather than forming square tile outlines.
	# This is a Nusantara renderer choice, not a recovered ACNH mesh algorithm.
	var x: int = floori(position.x / IslandDefinition.TILE_SIZE)
	var z: int = floori(position.z / IslandDefinition.TILE_SIZE)
	var accumulated := Color(0.0, 0.0, 0.0)
	var total_weight: float = 0.0
	for iz in range(z - 1, z + 2):
		for ix in range(x - 1, x + 2):
			if not island.contains(ix, iz):
				continue
			if island.height_at(ix, iz) != level:
				continue
			var style: Dictionary = island.terrain_layer_at(ix, iz, 0)
			var unit: int = int(style["unit"])
			if unit == 0:
				continue
			var u: float = position.x / IslandDefinition.TILE_SIZE - (float(ix) + 0.5)
			var v: float = position.z / IslandDefinition.TILE_SIZE - (float(iz) + 0.5)
			var radius: float = Vector2(u, v).length()
			if radius >= 0.82:
				continue
			var rotation: int = int(style["rotation"])
			var uv: Vector2 = Vector2(u, v).rotated(float(rotation) * PI * 0.5)
			var variant: int = IslandDefinition.effective_visual_variation(unit, int(style["variation"]))
			var streak: float = sin(uv.x * (10.0 + float(variant) * 1.7) + uv.y * 3.1)
			var weight: float = (1.0 - smoothstep(0.21, 0.82, radius)) * (0.85 + 0.09 * streak)
			var palette: Color = Color(0.63, 0.37, 0.23)
			match unit:
				2: palette = Color(0.21, 0.40, 0.24)
				3: palette = Color(0.68, 0.65, 0.51)
			accumulated += palette * weight
			total_weight += weight
	if total_weight <= 0.0:
		return result
	return result.lerp(accumulated / total_weight, minf(0.91, total_weight * 0.92) * (1.0 - wet * 0.73))


static func _add_ground_detail(tool: SurfaceTool, island: IslandDefinition, x: int, z: int) -> void:
	var layer: Dictionary = island.terrain_layer_at(x, z, 1)
	var unit: int = int(layer["unit"])
	if unit == 0:
		return
	var variant: int = IslandDefinition.effective_visual_variation(unit, int(layer["variation"]))
	var rotation: float = float(layer["rotation"]) * PI * 0.5
	var base_x: float = (float(x) + 0.5) * IslandDefinition.TILE_SIZE
	var base_z: float = (float(z) + 0.5) * IslandDefinition.TILE_SIZE
	var count: int = 3 + variant
	for index in range(count):
		var angle: float = float(index) * TAU / float(count) + rotation + 0.22 * float(variant)
		var distance: float = 0.22 + 0.06 * float(index % 2)
		var sx: float = base_x + cos(angle) * distance
		var sz: float = base_z + sin(angle) * distance
		var sy: float = RiverBathymetry.floor_height_at(island, sx, sz, island.height_at(x, z)) + 0.028
		var center := Vector3(sx, sy, sz)
		var long_axis := Vector3(cos(angle + rotation), 0.0, sin(angle + rotation)) * 0.13
		var short_axis := Vector3(-sin(angle + rotation), 0.0, cos(angle + rotation)) * 0.065
		var tone: Color = Color(0.62, 0.61, 0.52)
		match unit:
			2: tone = Color(0.25, 0.45, 0.18)
			3: tone = Color(0.85, 0.53, 0.26)
		_emit_quad(tool, center - long_axis - short_axis, center + long_axis - short_axis, center + long_axis + short_axis, center - long_axis + short_axis, tone)


static func _add_wall_and_lip(tool: SurfaceTool, lip_tool: SurfaceTool, island: IslandDefinition, x: int, z: int, direction: int, high: int, low: int, rounded: Array[bool], trim_start: float = 0.0, trim_end: float = 1.0) -> void:
	var high_y: float = float(high) * IslandDefinition.HEIGHT_STEP
	var low_y: float = float(low) * IslandDefinition.HEIGHT_STEP
	var start_t: float = maxf((CORNER_RADIUS / IslandDefinition.TILE_SIZE) if rounded[direction] else 0.0, trim_start)
	var end_t: float = minf((1.0 - CORNER_RADIUS / IslandDefinition.TILE_SIZE) if rounded[(direction + 1) % 4] else 1.0, trim_end)
	if end_t <= start_t:
		return
	for i in range(EDGE_SUBDIVISIONS):
		var a: float = lerpf(start_t, end_t, float(i) / float(EDGE_SUBDIVISIONS))
		var b: float = lerpf(start_t, end_t, float(i + 1) / float(EDGE_SUBDIVISIONS))
		var outer_a: float = _lip_width(island, x, z, direction, a)
		var outer_b: float = _lip_width(island, x, z, direction, b)
		var origin_a := _edge_position(x, z, direction, a, 0.0, high_y)
		var origin_b := _edge_position(x, z, direction, b, 0.0, high_y)
		var tip_a := _edge_position(x, z, direction, a, outer_a, high_y)
		var tip_b := _edge_position(x, z, direction, b, outer_b, high_y)
		var green := Color(0.245, 0.425, 0.18)
		# Keep the grass lip facing upward so its normals catch daylight.
		_emit_quad(lip_tool, origin_a, origin_b, tip_b, tip_a, green)
		for row in range(WALL_ROWS):
			var upper: float = float(row) / float(WALL_ROWS)
			var lower: float = float(row + 1) / float(WALL_ROWS)
			var upper_y: float = lerpf(high_y, low_y, upper)
			var lower_y: float = lerpf(high_y, low_y, lower)
			var p0 := _edge_position(x, z, direction, a, _wall_offset(island, x, z, direction, a, upper), upper_y)
			var p1 := _edge_position(x, z, direction, b, _wall_offset(island, x, z, direction, b, upper), upper_y)
			var p2 := _edge_position(x, z, direction, b, _wall_offset(island, x, z, direction, b, lower), lower_y)
			var p3 := _edge_position(x, z, direction, a, _wall_offset(island, x, z, direction, a, lower), lower_y)
			_emit_facet_quad(tool, p0, p1, p2, p3,
				_cliff_color(island, p0, upper), _cliff_color(island, p1, upper),
				_cliff_color(island, p2, lower), _cliff_color(island, p3, lower))


static func _add_rounded_corner(tool: SurfaceTool, lip_tool: SurfaceTool, island: IslandDefinition, x: int, z: int, corner: int, high: int, low: int) -> void:
	var high_y: float = float(high) * IslandDefinition.HEIGHT_STEP
	var low_y: float = float(low) * IslandDefinition.HEIGHT_STEP
	var incoming: int = (corner + 3) % 4
	var fraction: float = CORNER_RADIUS / IslandDefinition.TILE_SIZE
	for i in range(CORNER_SUBDIVISIONS):
		var a: float = float(i) / float(CORNER_SUBDIVISIONS)
		var b: float = float(i + 1) / float(CORNER_SUBDIVISIONS)
		var origin_a := _corner_arc_position(x, z, corner, a, 0.0, high_y)
		var origin_b := _corner_arc_position(x, z, corner, b, 0.0, high_y)
		var lip_a: float = lerpf(_lip_width(island, x, z, incoming, 1.0 - fraction), _lip_width(island, x, z, corner, fraction), a)
		var lip_b: float = lerpf(_lip_width(island, x, z, incoming, 1.0 - fraction), _lip_width(island, x, z, corner, fraction), b)
		var tip_a := _corner_arc_position(x, z, corner, a, lip_a, high_y)
		var tip_b := _corner_arc_position(x, z, corner, b, lip_b, high_y)
		_emit_quad(lip_tool, origin_a, origin_b, tip_b, tip_a, Color(0.245, 0.425, 0.18))
		for row in range(WALL_ROWS):
			var upper: float = float(row) / float(WALL_ROWS)
			var lower: float = float(row + 1) / float(WALL_ROWS)
			var upper_y: float = lerpf(high_y, low_y, upper)
			var lower_y: float = lerpf(high_y, low_y, lower)
			var p0 := _corner_arc_position(x, z, corner, a, _corner_wall_offset(island, x, z, corner, a, upper), upper_y)
			var p1 := _corner_arc_position(x, z, corner, b, _corner_wall_offset(island, x, z, corner, b, upper), upper_y)
			var p2 := _corner_arc_position(x, z, corner, b, _corner_wall_offset(island, x, z, corner, b, lower), lower_y)
			var p3 := _corner_arc_position(x, z, corner, a, _corner_wall_offset(island, x, z, corner, a, lower), lower_y)
			_emit_facet_quad(tool, p0, p1, p2, p3,
				_cliff_color(island, p0, upper), _cliff_color(island, p1, upper),
				_cliff_color(island, p2, lower), _cliff_color(island, p3, lower))


static func _cliff_color(island: IslandDefinition, point: Vector3, depth_factor: float) -> Color:
	var seed: float = float(island.seed % 233) * 0.01
	var seams: float = (0.032 * sin(point.x * 1.92 + point.z * 1.43 + seed)
		+ 0.017 * sin(point.x * 7.13 - point.z * 3.41 - depth_factor * 2.3))
	var sunlight := Color(0.66, 0.515, 0.344)
	var mid := Color(0.49, 0.368, 0.25)
	var shadow := Color(0.37, 0.317, 0.245)
	var pigment: Color = sunlight.lerp(mid, smoothstep(0.02, 0.65, depth_factor))
	pigment = pigment.lerp(shadow, smoothstep(0.57, 1.0, depth_factor))
	return Color(pigment.r + seams, pigment.g + seams * 0.77, pigment.b + seams * 0.52)


static func _corner_wall_offset(island: IslandDefinition, x: int, z: int, corner: int, t: float, depth_factor: float) -> float:
	var fraction: float = CORNER_RADIUS / IslandDefinition.TILE_SIZE
	var incoming: int = (corner + 3) % 4
	var a: float = _wall_offset(island, x, z, incoming, 1.0 - fraction, depth_factor)
	var b: float = _wall_offset(island, x, z, corner, fraction, depth_factor)
	return lerpf(a, b, t) + 0.018 * sin(PI * t) * sin(PI * depth_factor)


static func _corner_arc_position(x: int, z: int, corner: int, t: float, out: float, y: float, radius_override: float = CORNER_RADIUS) -> Vector3:
	var size: float = IslandDefinition.TILE_SIZE
	var radius: float = radius_override
	var center_x: float = float(x) * size + (size - radius if corner == 1 or corner == 2 else radius)
	var center_z: float = float(z) * size + (size - radius if corner == 2 or corner == 3 else radius)
	var start_angle: float = (float(corner) - 2.0) * PI * 0.5
	var angle: float = start_angle + t * PI * 0.5
	var arc_direction := Vector2(cos(angle), sin(angle))
	var start_direction := Vector2(cos(start_angle), sin(start_angle))
	var end_direction := Vector2(cos(start_angle + PI * 0.5), sin(start_angle + PI * 0.5))
	# Blend the quarter-circle with a 45-degree chamfer; pure arcs look too pillowy.
	var direction: Vector2 = start_direction.lerp(end_direction, t).lerp(arc_direction, CORNER_ARC_MIX)
	return Vector3(center_x + (radius + out) * direction.x, y, center_z + (radius + out) * direction.y)


static func _edge_position(x: int, z: int, direction: int, t: float, out: float, y: float) -> Vector3:
	var size: float = IslandDefinition.TILE_SIZE
	match direction:
		0:
			return Vector3((float(x) + t) * size, y, float(z) * size - out)
		1:
			return Vector3(float(x + 1) * size + out, y, (float(z) + t) * size)
		2:
			return Vector3((float(x + 1) - t) * size, y, float(z + 1) * size + out)
		_:
			return Vector3(float(x) * size - out, y, (float(z + 1) - t) * size)


static func _lip_width(island: IslandDefinition, x: int, z: int, direction: int, t: float) -> float:
	var world: float = (float(x) + t) if direction == 0 else ((float(z) + t) if direction == 1 else ((float(x + 1) - t) if direction == 2 else (float(z + 1) - t)))
	var side: float = float(z) if direction == 0 else (float(x + 1) if direction == 1 else (float(z + 1) if direction == 2 else float(x)))
	var seed: float = float(island.seed % 233) * 0.01
	return 0.12 + 0.041 * sin(world * 5.3 + side * 1.7 + seed) + 0.020 * sin(world * 11.7 + side * 3.5 + seed)


static func _wall_offset(island: IslandDefinition, x: int, z: int, direction: int, t: float, depth_factor: float) -> float:
	var lip: float = _lip_width(island, x, z, direction, t)
	# World-space coordinates keep adjacent tiles on the same cliff line seam-free.
	var along: float = (float(x) + t) if direction == 0 else ((float(z) + t) if direction == 1 else ((float(x + 1) - t) if direction == 2 else (float(z + 1) - t)))
	var side: float = float(z) if direction == 0 else (float(x + 1) if direction == 1 else (float(z + 1) if direction == 2 else float(x)))
	var seed: float = float(island.seed % 233) * 0.01
	# Broad outward belly plus irregular long rock facets. Both are calculated
	# in world coordinates so adjacent exposed walls share boundary vertices.
	var belly: float = 0.135 * sin(depth_factor * PI) * (0.78 + 0.22 * sin(along * 3.1 + side * 0.8 + seed))
	var facets: float = (0.038 * sin(along * 5.6 + depth_factor * 2.1 + seed)
		+ 0.017 * sin(along * 11.4 - depth_factor * 4.7 - seed)) * sin(depth_factor * PI)
	return lip * (1.0 - depth_factor) + belly + facets


static func _emit_facet_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_emit_facet_triangle(tool, a, b, c, ca, cb, cc)
	_emit_facet_triangle(tool, a, c, d, ca, cc, cd)


static func _emit_facet_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for vertex in [[a, ca], [c, cc], [b, cb]]:
		tool.set_color(vertex[1])
		tool.add_vertex(vertex[0])


static func _emit_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_emit_triangle(tool, a, b, c, color)
	_emit_triangle(tool, a, c, d, color)


static func _emit_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# SurfaceTool's normal generation follows Godot's clockwise front-face convention.
	# Emit c before b to make our map-space +Y top surfaces face upward.
	tool.set_color(color)
	tool.add_vertex(a)
	tool.set_color(color)
	tool.add_vertex(c)
	tool.set_color(color)
	tool.add_vertex(b)


static func _emit_colored_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color_a: Color, color_b: Color, color_c: Color) -> void:
	# Perimeter order is clockwise in XZ; this fan uses the opposite input winding
	# from the wall quads, resulting in outward-facing (+Y) ground normals.
	tool.set_color(color_a)
	tool.add_vertex(a)
	tool.set_color(color_b)
	tool.add_vertex(b)
	tool.set_color(color_c)
	tool.add_vertex(c)
