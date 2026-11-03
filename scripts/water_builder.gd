class_name WaterBuilder
extends RefCounted
## Original modular river renderer: wavy banks, animated surface, and waterfalls.
## This is an illustrative design, not a port of ACNH rendering code.

const EDGE_SEGMENTS: int = 14
const CORNER_SEGMENTS: int = 8
const FALL_ROWS: int = 12
const SPRAY_BANDS: int = 6
const WATER_ABOVE_GROUND: float = -0.08

const WATER_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color = vec4(0.065, 0.32, 0.40, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.56;
	for (int i = 0; i < 4; i++) {
		total += amplitude * noise21(p);
		p = mat2(vec2(1.71, 1.16), vec2(-1.16, 1.71)) * p + vec2(7.1, 3.9);
		amplitude *= 0.49;
	}
	return total;
}

void vertex() {
	float small = sin(VERTEX.x * 1.7 + VERTEX.z * 1.12 + TIME * 1.05);
	float other = sin(VERTEX.x * 0.93 - VERTEX.z * 1.43 - TIME * 0.83);
	VERTEX.y += 0.011 * small + 0.008 * other;
}

void fragment() {
	// COLOR.rg holds the interpolated gameplay flow, encoded as [0,1].
	// Small phase advection keeps the texture world-continuous even when water
	// changes direction at a bend; the flow is never used as a hard UV offset.
	vec2 flow = COLOR.rg * 2.0 - 1.0;
	float flow_strength = clamp(length(flow), 0.0, 1.0);
	vec2 dir = normalize(flow + vec2(0.0001, 0.0001));
	vec2 ambient = vec2(0.11, -0.08);
	vec2 motion = mix(ambient, dir * 0.13, flow_strength * 0.63);
	vec2 world = UV / 0.22;
	vec2 drift = world * 0.75 - motion * TIME;
	float broad = fbm(drift * 0.62);
	vec2 warp = vec2(noise21(drift * 0.82 + vec2(3.1, 9.2)), noise21(drift * 0.86 - vec2(6.5, 2.7))) - 0.5;
	float eddies = fbm(drift * 1.68 + warp * 0.81);
	float micro = noise21(world * 3.7 - motion * TIME * 1.5 + warp * 0.4);

	// Sparse, curved short wavelets, aligned across the local stream direction.
	// Their envelope is finite in both axes to avoid repeated diagonal bands.
	vec2 wave_cell_pos = (world + vec2(2.4, 5.6)) * 0.57;
	vec2 cell = floor(wave_cell_pos);
	vec2 local = (fract(wave_cell_pos) - 0.5) * 1.75;
	vec2 center = (vec2(hash21(cell + vec2(2.4, 7.1)), hash21(cell + vec2(9.3, 1.7))) - 0.5) * 0.25;
	vec2 q = local - center;
	vec2 wave_dir = normalize(mix(vec2(0.75, 0.66), dir, flow_strength));
	float across = dot(q, vec2(-wave_dir.y, wave_dir.x));
	float along = dot(q, wave_dir);
	float advancing = 0.11 * sin(TIME * 1.32 + hash21(cell) * 6.28318);
	float arc = exp(-abs(along + 0.53 * across * across - advancing) * 18.0);
	arc *= 1.0 - smoothstep(0.28, 0.59, abs(across));
	arc *= smoothstep(0.75, 0.96, hash21(cell + vec2(8.1, 4.2)));
	float highlight = arc * (0.32 + 0.55 * flow_strength);
	ALBEDO = tint.rgb * (0.74 + 0.19 * broad + 0.14 * eddies)
		+ vec3(0.033, 0.058, 0.062) * (0.38 * micro + highlight);
	ROUGHNESS = 0.22 + 0.16 * (1.0 - eddies);
	METALLIC = 0.04;
	// At a sea outlet the river becomes transparent over the lower ocean mesh,
	// eliminating the flat blue rectangle ending at the map border.
	ALPHA = 0.91 * COLOR.a;
}
"""

const SHORE_FOAM_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
varying vec2 world_point;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float patch = noise21(world_point * 0.76 + vec2(5.9, 3.2));
	float moving = noise21(world_point * 4.1 + vec2(-TIME * 0.38, TIME * 0.24));
	float fractured = smoothstep(0.44, 0.73, moving + 0.12 * sin(world_point.x * 4.6 + TIME));
	float intermittent = smoothstep(0.25, 0.77, patch);
	ALBEDO = mix(vec3(0.75, 0.94, 0.92), vec3(0.93, 0.98, 0.91), moving);
	ALPHA = COLOR.a * (0.09 + 0.69 * fractured * intermittent);
}
"""

const PLUNGE_FOAM_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
varying vec2 world_point;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 drifting = world_point + vec2(TIME * 0.11, -TIME * 0.07);
	float cloud = noise21(drifting * 2.9 + vec2(3.5, 5.4));
	float lacing = noise21(drifting * 9.6 + vec2(0.4, 7.2));
	float bubbles = smoothstep(0.43, 0.78, cloud * 0.78 + lacing * 0.22);
	ALBEDO = mix(vec3(0.79, 0.93, 0.93), vec3(0.96, 0.99, 0.96), lacing);
	ALPHA = COLOR.a * (0.09 + 0.85 * bubbles);
}
"""

const FALL_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tint : source_color = vec4(0.085, 0.37, 0.48, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 falling = vec2(UV.x * 7.8, UV.y * 5.9 - TIME * 2.0);
	float turbulence = noise21(falling + vec2(noise21(falling * 0.62), 0.0));
	float rivulets = noise21(vec2(falling.x * 4.3 + turbulence * 0.92, falling.y * 0.46));
	float splash = noise21(falling * 3.2 + vec2(TIME * 0.21, -TIME * 0.56));
	float strands = smoothstep(0.44, 0.76, rivulets);
	float thin_threads = smoothstep(0.62, 0.82, noise21(vec2(falling.x * 8.9 + turbulence, falling.y * 0.59)));
	float glow = strands * 0.55 + thin_threads * 0.33;
	ALBEDO = tint.rgb * (0.82 + 0.23 * turbulence)
		+ vec3(0.20, 0.27, 0.26) * glow + vec3(0.05, 0.09, 0.09) * splash;
	EMISSION = tint.rgb * 0.25 + vec3(0.12, 0.17, 0.17) * glow;
	ROUGHNESS = 0.23;
	ALPHA = (0.79 + 0.08 * turbulence) * COLOR.a;
}
"""

const FALL_MIST_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
varying vec2 world_point;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 phase = world_point * vec2(4.7, 3.3) + vec2(TIME * 0.15, -TIME * 0.76);
	float cloud = noise21(phase) * 0.66 + noise21(phase * 2.3) * 0.34;
	float wisps = smoothstep(0.34, 0.79, cloud);
	ALBEDO = mix(vec3(0.54, 0.82, 0.84), vec3(0.85, 0.96, 0.94), wisps);
	ALPHA = COLOR.a * (0.16 + 0.68 * wisps);
}
"""


static func build_world(island: IslandDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Hydrology"
	var water_tool := _new_tool()
	var banks_tool := _new_tool()
	var foam_tool := _new_tool()
	var falls_tool := _new_tool()
	var fall_foam_tool := _new_tool()
	var fall_mist_tool := _new_tool()
	var trigger_root := Node3D.new()
	trigger_root.name = "WaterTriggers"
	root.add_child(trigger_root)
	var contour := RiverContour.new(island)
	var generated: Dictionary = contour.append_mesh(water_tool, banks_tool, foam_tool)
	var wet_count: int = 0
	var falling_edges: int = 0
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			wet_count += 1
			_add_water_trigger(trigger_root, island, x, z)
			for direction in range(4):
				var adjacent: Vector2i = _neighbor(x, z, direction)
				if island.is_water(adjacent.x, adjacent.y) and island.height_at(adjacent.x, adjacent.y) < island.height_at(x, z):
					falling_edges += 1
					_add_waterfall(falls_tool, fall_foam_tool, fall_mist_tool, island, x, z, direction, island.height_at(adjacent.x, adjacent.y))
	_add_mesh(root, "WaterSurface", water_tool, _water_material(), wet_count > 0)
	var bank_mesh: Mesh = _add_mesh(root, "RiverBanks", banks_tool, _bank_material(), int(generated["bank_segments"]) > 0)
	_add_mesh(root, "ShoreFoam", foam_tool, _shore_foam_material(), int(generated["foam_segments"]) > 0)
	_add_mesh(root, "Waterfalls", falls_tool, _fall_material(), falling_edges > 0)
	_add_mesh(root, "FallFoam", fall_foam_tool, _foam_material(), falling_edges > 0)
	_add_mesh(root, "FallMist", fall_mist_tool, _mist_material(), falling_edges > 0)
	if bank_mesh != null:
		var collision_body := StaticBody3D.new()
		collision_body.name = "RiverBankCollision"
		var collision := CollisionShape3D.new()
		collision.shape = bank_mesh.create_trimesh_shape()
		collision_body.add_child(collision)
		root.add_child(collision_body)
	return root


static func _new_tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add_mesh(root: Node3D, item_name: String, tool: SurfaceTool, material: Material, has_vertices: bool) -> Mesh:
	if not has_vertices:
		return null
	tool.generate_normals()
	var item := MeshInstance3D.new()
	item.name = item_name
	item.mesh = tool.commit()
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(item)
	return item.mesh


static func _water_material() -> Material:
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _fall_material() -> Material:
	var shader := Shader.new()
	shader.code = FALL_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _bank_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.91
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _foam_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = PLUNGE_FOAM_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	# Plunge spray is translucent, but must render after the water curtain.
	material.render_priority = 2
	return material


static func _mist_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = FALL_MIST_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 3
	return material


static func _shore_foam_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHORE_FOAM_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _neighbor(x: int, z: int, direction: int) -> Vector2i:
	match direction:
		0:
			return Vector2i(x, z - 1)
		1:
			return Vector2i(x + 1, z)
		2:
			return Vector2i(x, z + 1)
		_:
			return Vector2i(x - 1, z)


static func _water_height(island: IslandDefinition, x: int, z: int) -> float:
	return float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP + WATER_ABOVE_GROUND


static func _shore_inset(island: IslandDefinition, x: int, z: int, direction: int, t: float) -> float:
	var along: float = (float(x) + t) if direction == 0 else ((float(z) + t) if direction == 1 else ((float(x + 1) - t) if direction == 2 else (float(z + 1) - t)))
	var side: float = float(z) if direction == 0 else (float(x + 1) if direction == 1 else (float(z + 1) if direction == 2 else float(x)))
	var seed: float = float(island.seed % 307) * 0.007
	return 0.17 + 0.054 * sin(along * 3.9 + side * 1.3 + seed) + 0.021 * sin(along * 9.1 - side * 2.7 + seed)


static func _shore_corners(island: IslandDefinition, x: int, z: int) -> Array[bool]:
	var result: Array[bool] = [false, false, false, false]
	for corner in range(4):
		var previous: Vector2i = _neighbor(x, z, (corner + 3) % 4)
		var following: Vector2i = _neighbor(x, z, corner)
		result[corner] = not island.is_water(previous.x, previous.y) and not island.is_water(following.x, following.y)
	return result


static func _edge_point(island: IslandDefinition, x: int, z: int, direction: int, t: float, y: float, additional_inset: float = 0.0) -> Vector3:
	var adjacent: Vector2i = _neighbor(x, z, direction)
	var shore: bool = not island.is_water(adjacent.x, adjacent.y)
	var inset: float = (_shore_inset(island, x, z, direction, t) + additional_inset) if shore else 0.0
	if shore:
		var previous: Vector2i = _neighbor(x, z, (direction + 3) % 4)
		var following: Vector2i = _neighbor(x, z, (direction + 1) % 4)
		if island.is_water(previous.x, previous.y):
			inset *= smoothstep(0.0, 0.22, t)
		if island.is_water(following.x, following.y):
			inset *= smoothstep(0.0, 0.22, 1.0 - t)
	return TerrainBuilder._edge_position(x, z, direction, t, -inset, y)


static func _corner_point(island: IslandDefinition, x: int, z: int, corner: int, t: float, y: float) -> Vector3:
	var fraction: float = TerrainBuilder.CORNER_RADIUS / IslandDefinition.TILE_SIZE
	var incoming: int = (corner + 3) % 4
	var start_inset: float = _shore_inset(island, x, z, incoming, 1.0 - fraction)
	var end_inset: float = _shore_inset(island, x, z, corner, fraction)
	var inset: float = lerpf(start_inset, end_inset, t)
	return TerrainBuilder._corner_arc_position(x, z, corner, t, -inset, y)


static func _add_water_tile(tool: SurfaceTool, island: IslandDefinition, x: int, z: int) -> void:
	var size: float = IslandDefinition.TILE_SIZE
	var water_y: float = _water_height(island, x, z)
	var center := Vector3((float(x) + 0.5) * size, water_y, (float(z) + 0.5) * size)
	var perimeter: Array[Vector3] = []
	var rounded: Array[bool] = _shore_corners(island, x, z)
	var fraction: float = TerrainBuilder.CORNER_RADIUS / size
	for direction in range(4):
		var start_t: float = fraction if rounded[direction] else 0.0
		var end_t: float = (1.0 - fraction) if rounded[(direction + 1) % 4] else 1.0
		for i in range(EDGE_SEGMENTS):
			var t: float = lerpf(start_t, end_t, float(i) / float(EDGE_SEGMENTS))
			perimeter.append(_edge_point(island, x, z, direction, t, water_y))
		if rounded[(direction + 1) % 4]:
			for i in range(CORNER_SEGMENTS):
				perimeter.append(_corner_point(island, x, z, (direction + 1) % 4, float(i) / float(CORNER_SEGMENTS), water_y))
	for i in range(perimeter.size()):
		_emit_surface_triangle(tool, center, perimeter[i], perimeter[(i + 1) % perimeter.size()])


static func _add_shore(banks_tool: SurfaceTool, foam_tool: SurfaceTool, island: IslandDefinition, x: int, z: int, direction: int) -> int:
	var base_y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP
	var water_y: float = _water_height(island, x, z)
	var wet_soil := Color(0.46, 0.48, 0.32) if island.height_at(x, z) > 0 else Color(0.57, 0.56, 0.40)
	var patches: int = 0
	var rounded: Array[bool] = _shore_corners(island, x, z)
	var fraction: float = TerrainBuilder.CORNER_RADIUS / IslandDefinition.TILE_SIZE
	var start_t: float = fraction if rounded[direction] else 0.0
	var end_t: float = (1.0 - fraction) if rounded[(direction + 1) % 4] else 1.0
	for i in range(EDGE_SEGMENTS):
		var a: float = lerpf(start_t, end_t, float(i) / float(EDGE_SEGMENTS))
		var b: float = lerpf(start_t, end_t, float(i + 1) / float(EDGE_SEGMENTS))
		var inner_a: Vector3 = _edge_point(island, x, z, direction, a, water_y - 0.006)
		var inner_b: Vector3 = _edge_point(island, x, z, direction, b, water_y - 0.006)
		var outer_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, 0.0, base_y + 0.025)
		var outer_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, 0.0, base_y + 0.025)
		_emit_quad(banks_tool, inner_a, inner_b, outer_b, outer_a, wet_soil)
		# Sparse, width-varied shoreline foam patches, not a continuous stripe.
		var along: float = float(x * 19 + z * 13 + i * 7 + direction * 11)
		if sin(along * 0.37) + sin(along * 0.19) > 1.32:
			patches += 1
			var foam_a: Vector3 = _edge_point(island, x, z, direction, a, water_y + 0.016, 0.018)
			var foam_b: Vector3 = _edge_point(island, x, z, direction, b, water_y + 0.016, 0.018)
			var depth: float = 0.026 + 0.021 * abs(sin(along * 0.57))
			var foam_inner_a: Vector3 = _edge_point(island, x, z, direction, a, water_y + 0.016, depth)
			var foam_inner_b: Vector3 = _edge_point(island, x, z, direction, b, water_y + 0.016, depth)
			_emit_quad(foam_tool, foam_inner_a, foam_inner_b, foam_b, foam_a, Color(0.84, 0.95, 0.96, 0.085))
	return patches


static func _add_corner_bank(tool: SurfaceTool, island: IslandDefinition, x: int, z: int, corner: int) -> void:
	var base_y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP
	var water_y: float = _water_height(island, x, z)
	var bank_color := Color(0.46, 0.48, 0.32) if island.height_at(x, z) > 0 else Color(0.57, 0.56, 0.40)
	for i in range(CORNER_SEGMENTS):
		var a: float = float(i) / float(CORNER_SEGMENTS)
		var b: float = float(i + 1) / float(CORNER_SEGMENTS)
		var inner_a: Vector3 = _corner_point(island, x, z, corner, a, water_y - 0.006)
		var inner_b: Vector3 = _corner_point(island, x, z, corner, b, water_y - 0.006)
		var outer_a: Vector3 = TerrainBuilder._corner_arc_position(x, z, corner, a, 0.0, base_y + 0.025)
		var outer_b: Vector3 = TerrainBuilder._corner_arc_position(x, z, corner, b, 0.0, base_y + 0.025)
		_emit_quad(tool, inner_a, inner_b, outer_b, outer_a, bank_color)


static func _add_waterfall(tool: SurfaceTool, foam_tool: SurfaceTool, mist_tool: SurfaceTool, island: IslandDefinition, x: int, z: int, direction: int, low: int) -> void:
	var top_y: float = _water_height(island, x, z)
	var bottom_y: float = float(low) * IslandDefinition.HEIGHT_STEP + WATER_ABOVE_GROUND
	var span: Vector2 = _fall_interval(island, x, z, direction, island.height_at(x, z), low)
	for segment in range(EDGE_SEGMENTS):
		var a: float = lerpf(span.x, span.y, float(segment) / float(EDGE_SEGMENTS))
		var b: float = lerpf(span.x, span.y, float(segment + 1) / float(EDGE_SEGMENTS))
		var feather_a: float = _fall_fade(a, span)
		var feather_b: float = _fall_fade(b, span)
		var tint_a := Color(1.0, 1.0, 1.0, feather_a)
		var tint_b := Color(1.0, 1.0, 1.0, feather_b)
		var edge_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, 0.0, top_y)
		var edge_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, 0.0, top_y)
		var outer_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, 0.19, top_y)
		var outer_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, 0.19, top_y)
		_emit_tinted_quad(tool, edge_a, edge_b, outer_b, outer_a, tint_a, tint_b, tint_b, tint_a)
		# Wet crest shoulders bridge a few centimeters into the upper river,
		# reducing the thin rock-colored seam at the waterfall takeoff.
		var back_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, -0.115, top_y + 0.009)
		var back_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, -0.115, top_y + 0.009)
		var shoulder_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, 0.255, top_y + 0.009)
		var shoulder_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, 0.255, top_y + 0.009)
		var crest_a := Color(1.0, 1.0, 1.0, feather_a * 0.35)
		var crest_b := Color(1.0, 1.0, 1.0, feather_b * 0.35)
		_emit_tinted_quad(tool, back_a, back_b, shoulder_b, shoulder_a, crest_a, crest_b, crest_b, crest_a)
		# Three nearby sheets share the lip at top and rejoin at the bottom. Their
		# bellies separate in the middle and produce real geometric thickness.
		for sheet in range(3):
			var opacity: float = 1.0 if sheet == 0 else (0.31 if sheet == 1 else 0.17)
			var layer_a := Color(1.0, 1.0, 1.0 - 0.12 * float(sheet), feather_a * opacity)
			var layer_b := Color(1.0, 1.0, 1.0 - 0.12 * float(sheet), feather_b * opacity)
			for row in range(FALL_ROWS):
				var upper: float = float(row) / float(FALL_ROWS)
				var lower: float = float(row + 1) / float(FALL_ROWS)
				var p0: Vector3 = _fall_point(x, z, direction, a, upper, top_y, bottom_y, sheet)
				var p1: Vector3 = _fall_point(x, z, direction, b, upper, top_y, bottom_y, sheet)
				var p2: Vector3 = _fall_point(x, z, direction, b, lower, top_y, bottom_y, sheet)
				var p3: Vector3 = _fall_point(x, z, direction, a, lower, top_y, bottom_y, sheet)
				_emit_tinted_quad(tool, p0, p1, p2, p3, layer_a, layer_b, layer_b, layer_a)
		# Feathered crescents at several distances from the plunge rather than
		# one long rectangular foam slab attached to the cliff.
		for band in range(SPRAY_BANDS):
			var breakup: float = sin(float(segment) * 1.13 + float(band) * 2.1)
			var near: float = 0.16 + float(band) * 0.126 + 0.038 * sin(float(segment) * 0.71 + float(band) * 1.4)
			var far: float = near + 0.14 + 0.077 * absf(sin(float(segment) * 0.97 + float(band) * 1.3))
			var spray_y: float = bottom_y + 0.083 - float(band) * 0.008
			var near_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, near, spray_y)
			var near_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, near, spray_y)
			var far_a: Vector3 = TerrainBuilder._edge_position(x, z, direction, a, far, spray_y)
			var far_b: Vector3 = TerrainBuilder._edge_position(x, z, direction, b, far, spray_y)
			var foamy: float = (0.61 - 0.076 * float(band)) * minf(feather_a, feather_b) * (0.55 + 0.45 * smoothstep(-0.5, 0.6, breakup))
			var edge_fade: float = 0.12 + 0.25 * absf(sin(float(band) * 1.76 + float(segment) * 0.46))
			var fade_a := Color(0.87, 0.97, 0.99, foamy * edge_fade)
			var fade_b := Color(0.87, 0.97, 0.99, foamy)
			_emit_tinted_quad(foam_tool, far_a, far_b, near_b, near_a, fade_a, fade_a, fade_b, fade_b)
	# Narrow animated translucent veils overlap the cliff-side fringe. They are
	# visual only: no new collider or game-state water region is introduced.
	for edge in range(2):
		var t_inside: float = span.x if edge == 0 else span.y
		var t_outside: float = clampf(t_inside + (-0.085 if edge == 0 else 0.085), 0.0, 1.0)
		for row in range(FALL_ROWS):
			var upper: float = float(row) / float(FALL_ROWS)
			var lower: float = float(row + 1) / float(FALL_ROWS)
			var seam_a: Vector3 = _fall_point(x, z, direction, t_inside, upper, top_y, bottom_y)
			var fringe_a: Vector3 = _fall_point(x, z, direction, t_outside, upper, top_y, bottom_y)
			var fringe_b: Vector3 = _fall_point(x, z, direction, t_outside, lower, top_y, bottom_y)
			var seam_b: Vector3 = _fall_point(x, z, direction, t_inside, lower, top_y, bottom_y)
			var fade: float = smoothstep(0.03, 0.20, upper) * (1.0 - smoothstep(0.83, 1.0, lower))
			var colored_seam := Color(1.0, 1.0, 1.0, 0.28 * fade)
			var colored_fringe := Color(1.0, 1.0, 1.0, 0.02 * fade)
			_emit_tinted_quad(mist_tool, seam_a, fringe_a, fringe_b, seam_b, colored_seam, colored_fringe, colored_fringe, colored_seam)
	# No opaque side caps: alpha feathering joins the sheet to the rock silhouette.


static func _fall_fade(t: float, span: Vector2) -> float:
	var width: float = maxf(span.y - span.x, 0.001)
	var edge: float = minf((t - span.x) / width, (span.y - t) / width)
	return 0.09 + 0.91 * smoothstep(0.0, 0.16, edge)


static func _fall_interval(island: IslandDefinition, x: int, z: int, direction: int, high: int, low: int) -> Vector2:
	var first: float = -1.0
	var last: float = -1.0
	for i in range(65):
		var t: float = float(i) / 64.0
		var upper: Vector3 = TerrainBuilder._edge_position(x, z, direction, t, -0.16, 0.0)
		var lower: Vector3 = TerrainBuilder._edge_position(x, z, direction, t, 0.16, 0.0)
		var upper_coverage: float = RiverContour.field_at(island, upper.x, upper.z, high)
		var lower_coverage: float = RiverContour.field_at(island, lower.x, lower.z, low)
		if minf(upper_coverage, lower_coverage) >= 0.445:
			if first < 0.0:
				first = t
			last = t
	if first < 0.0 or last - first < 0.05:
		return Vector2(0.0, 1.0)
	return Vector2(first, last)


static func _fall_point(x: int, z: int, direction: int, t: float, depth: float, high_y: float, low_y: float, sheet: int = 0) -> Vector3:
	var y: float = lerpf(high_y, low_y, depth)
	# The leading lip is exactly at 0.19 at depth=0, touching the crest bridge.
	var out: float = 0.19 + sin(depth * PI) * (0.085 + 0.042 * float(sheet)
		+ 0.022 * sin(t * TAU * 2.0 + depth * 4.0 + float(sheet) * 1.4))
	return TerrainBuilder._edge_position(x, z, direction, t, out, y)


static func _add_water_trigger(parent: Node3D, island: IslandDefinition, x: int, z: int) -> void:
	var area := Area3D.new()
	area.name = "Water_%s_%s" % [x, z]
	area.collision_layer = 2
	area.collision_mask = 1
	area.position = Vector3((float(x) + 0.5) * IslandDefinition.TILE_SIZE, _water_height(island, x, z), (float(z) + 0.5) * IslandDefinition.TILE_SIZE)
	var shape := BoxShape3D.new()
	shape.size = Vector3(IslandDefinition.TILE_SIZE * 0.88, 0.30, IslandDefinition.TILE_SIZE * 0.88)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	parent.add_child(area)


static func _emit_surface_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Clockwise top contour follows Godot's front-face convention for this fan.
	for p in [a, b, c]:
		tool.set_uv(Vector2(p.x, p.z) * 0.22)
		tool.add_vertex(p)


static func _emit_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_emit_triangle(tool, a, b, c, color)
	_emit_triangle(tool, a, c, d, color)


static func _emit_tinted_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_emit_tinted_triangle(tool, a, b, c, ca, cb, cc)
	_emit_tinted_triangle(tool, a, c, d, ca, cc, cd)


static func _emit_tinted_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for vertex in [[a, ca], [c, cc], [b, cb]]:
		var p: Vector3 = vertex[0]
		tool.set_color(vertex[1])
		tool.set_uv(Vector2(p.x + p.z, p.y) * 0.24)
		tool.add_vertex(p)


static func _emit_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# Reversed vertex order matches existing terrain wall normals.
	for p in [a, c, b]:
		tool.set_color(color)
		tool.set_uv(Vector2(p.x + p.z, p.y) * 0.24)
		tool.add_vertex(p)
