class_name CoastBuilder
extends RefCounted
## Ocean wave fronts and actual terrain silhouette share one shoreline profile.
## Ocean remains a visual background, not a traversable simulation zone.

const SEA_MARGIN: float = 9.0
const SEA_HEIGHT: float = -0.145
const PROFILE_SAMPLES: int = 512
const MASK_SDF_SAMPLES: int = 256
const GEOMETRIC_SDF_BLEND_START: float = 2.10
const GEOMETRIC_SDF_BLEND_END: float = 3.85
## Reuse expensive coast textures for the same island/revision. The revision
## changes for actual topology/shore/river/height mutations, not no-op writes.
static var _profile_cache_instance: int = -1
static var _profile_cache_revision: int = -1
static var _profile_cache: ImageTexture
static var _sdf_cache_instance: int = -1
static var _sdf_cache_revision: int = -1
static var _sdf_cache: ImageTexture

const OCEAN_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec2 island_extent = vec2(24.0, 18.0);
uniform sampler2D coast_profile : filter_linear, repeat_disable;
uniform sampler2D coast_sdf : filter_linear, repeat_disable;
uniform float use_coast_sdf = 0.0;
uniform float sea_margin = 9.0;
uniform float breaker_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wave_temporal_scale : hint_range(0.1, 3.0) = 1.0;
uniform float surf_train_rate : hint_range(0.03, 0.30) = 0.115;
varying vec2 world_point;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise21(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
// One finite wave train moving from offshore toward shore. The envelope
// goes to zero at both ends of its cycle; wrapping fract() is therefore
// invisible instead of creating a popping/discontinuous full-length ribbon.
float surf_train(float progress, float distance_to_shore, float curvature) {
	float center = mix(2.38, 0.18, progress) + curvature;
	float width = mix(0.14, 0.30, progress);
	float crest = exp(-pow((distance_to_shore - center) / width, 2.0));
	float birth = smoothstep(0.01, 0.17, progress);
	float break_up = 1.0 - smoothstep(0.79, 0.99, progress);
	return crest * birth * break_up;
}
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += 0.013 * sin(world_point.x * 1.11 + world_point.y * 1.51 - TIME * 0.9);
}
void fragment() {
	vec2 p = world_point;
	// The same sampled four boundary functions deform the ground collision mesh.
	// Red/green are west/east; blue/alpha are north/south boundaries.
	vec4 east_west = texture(coast_profile, vec2(clamp(p.y / island_extent.y, 0.0, 1.0), 0.5));
	vec4 north_south = texture(coast_profile, vec2(clamp(p.x / island_extent.x, 0.0, 1.0), 0.5));
	float perimeter_distance = max(max(east_west.r - p.x, p.x - east_west.g),
		max(north_south.b - p.y, p.y - north_south.a));
	vec2 shore_uv = clamp((p + vec2(sea_margin)) / (island_extent + vec2(2.0 * sea_margin)), vec2(0.0), vec2(1.0));
	float water_distance = mix(perimeter_distance, texture(coast_sdf, shore_uv).r, use_coast_sdf);
	float t = TIME * wave_temporal_scale;
	float near_shore = 1.0 - smoothstep(0.05, 3.25, water_distance);
	vec2 advected = p * 0.83 + vec2(-t * 0.13, t * 0.075);
	float broad = noise21(advected * 0.71);
	float chop = noise21(advected * 2.85 + vec2(5.4, 1.6));
	// The SDF normal turns waves along bays and around headlands. This is an
	// independently authored stylized sea shader, NOT a reverse-engineered one.
	vec2 coast_normal = vec2(1.0, 0.0);
	if (use_coast_sdf > 0.5) {
		vec2 pixel = vec2(1.0 / 256.0);
		coast_normal = normalize(vec2(
			texture(coast_sdf, shore_uv + vec2(pixel.x, 0.0)).r - texture(coast_sdf, shore_uv - vec2(pixel.x, 0.0)).r,
			texture(coast_sdf, shore_uv + vec2(0.0, pixel.y)).r - texture(coast_sdf, shore_uv - vec2(0.0, pixel.y)).r
		) + vec2(0.00001));
	}
	vec2 tangent = vec2(-coast_normal.y, coast_normal.x);
	float streak = noise21(p * 0.94 + vec2(t * 0.027, -t * 0.031));
	float patches = noise21(p * 2.13 + tangent * t * 0.064);
	float fracture = smoothstep(0.34, 0.73, patches + 0.13 * streak);
	float shore_shift = 0.12 * sin(dot(p, tangent) * 1.23 + t * 0.63)
		+ 0.11 * (streak - 0.5);
	// Sprint 50: two staggered, finite-duration breaker fronts advance from
	// offshore to shore. The 0.5 offset avoids both fronts resetting together.
	float phase_variation = 0.035 * sin(dot(p, tangent) * 0.61) + 0.035 * (streak - 0.5);
	float progress = fract(t * surf_train_rate + phase_variation);
	float front = surf_train(progress, water_distance, shore_shift);
	float companion = surf_train(fract(progress + 0.5), water_distance, shore_shift * 0.76);
	float post_break = smoothstep(0.66, 0.83, progress) * (1.0 - smoothstep(0.95, 1.0, progress));
	float returning = mix(0.14, 0.94, smoothstep(0.71, 0.98, progress));
	float backwash = exp(-pow((water_distance - returning) / 0.35, 2.0)) * post_break;
	float side = smoothstep(0.02, 0.13, water_distance);
	float foam = side * near_shore * ((front + 0.72 * companion) * (0.14 + 0.86 * fracture)
		+ 0.27 * backwash * smoothstep(0.49, 0.81, streak));
	foam += 0.16 * side * near_shore * (1.0 - smoothstep(0.0, 0.21, water_distance)) * fracture;
	foam *= breaker_strength;
	ALBEDO = mix(vec3(0.038, 0.19, 0.31), vec3(0.065, 0.35, 0.39), near_shore * 0.65)
		* (0.83 + 0.24 * broad + 0.14 * chop) + vec3(0.23, 0.29, 0.25) * foam;
	ROUGHNESS = 0.25 + 0.12 * (1.0 - broad) - 0.08 * clamp(foam, 0.0, 1.0);
	METALLIC = 0.035;
}
"""


static func build_world(island: IslandDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "CoastalOcean"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var has_masked_cells: bool = island.land_mask.count(0) > 0
	# The sea extends just inside the former grid outline. Wherever dry ground
	# recedes into an inlet, it reveals water instead of background sky.
	if has_masked_cells:
		# Single non-overlapping sea plane: the new sea cells expose actual water,
		# while the remaining ground meshes still fully occlude it.
		_emit_plane(tool, -SEA_MARGIN, w + SEA_MARGIN, -SEA_MARGIN, d + SEA_MARGIN)
	else:
		var overlap: float = minf(2.65, 0.27 * minf(w, d))
		_emit_plane(tool, -SEA_MARGIN, overlap, -SEA_MARGIN, d + SEA_MARGIN)
		_emit_plane(tool, w - overlap, w + SEA_MARGIN, -SEA_MARGIN, d + SEA_MARGIN)
		_emit_plane(tool, overlap, w - overlap, -SEA_MARGIN, overlap)
		_emit_plane(tool, overlap, w - overlap, d - overlap, d + SEA_MARGIN)
	tool.generate_normals()
	var ocean := MeshInstance3D.new()
	ocean.name = "OceanSurface"
	ocean.mesh = tool.commit()
	var shader := Shader.new()
	shader.code = OCEAN_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("island_extent", Vector2(w, d))
	material.set_shader_parameter("coast_profile", make_shoreline_texture(island))
	material.set_shader_parameter("use_coast_sdf", 1.0 if has_masked_cells else 0.0)
	material.set_shader_parameter("sea_margin", SEA_MARGIN)
	if has_masked_cells:
		material.set_shader_parameter("coast_sdf", make_signed_coast_texture(island))
	ocean.material_override = material
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ocean)
	return root


static func make_shoreline_texture(island: IslandDefinition) -> ImageTexture:
	if _profile_cache != null and _profile_cache_instance == island.get_instance_id() and _profile_cache_revision == island.coastline_revision:
		return _profile_cache
	# Baked from the exact CoastContour CPU boundaries: no duplicated shader
	# noise parameters, tile phase, wet-outlet suppression or editor offsets.
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var image := Image.create(PROFILE_SAMPLES, 1, false, Image.FORMAT_RGBAF)
	for index in range(PROFILE_SAMPLES):
		var t: float = float(index) / float(PROFILE_SAMPLES - 1)
		image.set_pixel(index, 0, Color(
			CoastContour.boundary_at(island, 0, t * d),
			CoastContour.boundary_at(island, 1, t * d),
			CoastContour.boundary_at(island, 2, t * w),
			CoastContour.boundary_at(island, 3, t * w)))
	_profile_cache = ImageTexture.create_from_image(image)
	_profile_cache_instance = island.get_instance_id()
	_profile_cache_revision = island.coastline_revision
	return _profile_cache


static func make_signed_coast_texture(island: IslandDefinition) -> ImageTexture:
	if _sdf_cache != null and _sdf_cache_instance == island.get_instance_id() and _sdf_cache_revision == island.coastline_revision:
		return _sdf_cache
	# Sprint 34: exact separable Euclidean distance to the rasterized shoreline.
	# A chamfer approximation underestimated diagonal clearance and distorted
	# surf ribbons at diagonal bays. Raster occupancy and movement use the
	# same on_island, including collidable concave inlet fillets.
	var side: int = MASK_SDF_SAMPLES
	var count: int = side * side
	var width_world: float = float(island.width) * IslandDefinition.TILE_SIZE + 2.0 * SEA_MARGIN
	var depth_world: float = float(island.depth) * IslandDefinition.TILE_SIZE + 2.0 * SEA_MARGIN
	var step_x: float = width_world / float(side - 1)
	var step_z: float = depth_world / float(side - 1)
	var flags := PackedByteArray()
	flags.resize(count)
	var distances_squared := PackedFloat32Array()
	distances_squared.resize(count)
	distances_squared.fill(100000000.0)
	for z in range(side):
		for x in range(side):
			flags[z * side + x] = 1 if CoastContour.on_island(island, -SEA_MARGIN + float(x) * step_x, -SEA_MARGIN + float(z) * step_z) else 0
	for z in range(side):
		for x in range(side):
			var index: int = z * side + x
			var inside: int = flags[index]
			if (x > 0 and flags[index - 1] != inside) or (x < side - 1 and flags[index + 1] != inside) or (z > 0 and flags[index - side] != inside) or (z < side - 1 and flags[index + side] != inside):
				distances_squared[index] = 0.0
	# First pass along X, second along Z. Both operate on squared distances,
	# then sqrt once when writing the GPU texture. Complexity: O(side²).
	var horizontal := PackedFloat32Array()
	horizontal.resize(count)
	for z in range(side):
		var source_row := PackedFloat32Array()
		source_row.resize(side)
		for x in range(side):
			source_row[x] = distances_squared[z * side + x]
		var result_row: PackedFloat32Array = _edt_1d(source_row, step_x)
		for x in range(side):
			horizontal[z * side + x] = result_row[x]
	var vertical := PackedFloat32Array()
	vertical.resize(count)
	for x in range(side):
		var source_column := PackedFloat32Array()
		source_column.resize(side)
		for z in range(side):
			source_column[z] = horizontal[z * side + x]
		var result_column: PackedFloat32Array = _edt_1d(source_column, step_z)
		for z in range(side):
			vertical[z * side + x] = result_column[z]
	var image := Image.create(side, side, false, Image.FORMAT_RF)
	for z in range(side):
		for x in range(side):
			var index: int = z * side + x
			var edge_distance: float = maxf(0.0, sqrt(vertical[index]) - 0.5 * minf(step_x, step_z))
			# Sprint 40: near the visible surf, replace raster-seed EDT distances
			# with distances to the SAME warped edge/skirt/fillet polylines used
			# by sand color. Blend back to fast EDT in deeper water. Restricting
			# the geometric query to a small band keeps edit rebuild affordable.
			if edge_distance < GEOMETRIC_SDF_BLEND_END:
				var wx: float = -SEA_MARGIN + float(x) * step_x
				var wz: float = -SEA_MARGIN + float(z) * step_z
				var geometric_distance: float = CoastContour.distance_to_coast(island, wx, wz)
				var weight: float = 1.0 - smoothstep(GEOMETRIC_SDF_BLEND_START, GEOMETRIC_SDF_BLEND_END, edge_distance)
				edge_distance = lerpf(edge_distance, geometric_distance, weight)
			image.set_pixel(x, z, Color(-edge_distance if flags[index] != 0 else edge_distance, 0.0, 0.0))
	_sdf_cache = ImageTexture.create_from_image(image)
	_sdf_cache_instance = island.get_instance_id()
	_sdf_cache_revision = island.coastline_revision
	return _sdf_cache


static func _edt_1d(input: PackedFloat32Array, spacing: float) -> PackedFloat32Array:
	# Lower-envelope of parabolas: exact squared Euclidean distance in one
	# dimension. All values are finite and below 1e8 in practical terrain maps.
	var n: int = input.size()
	var result := PackedFloat32Array()
	result.resize(n)
	if n == 0:
		return result
	var vertices := PackedInt32Array()
	vertices.resize(n)
	var breaks := PackedFloat32Array()
	breaks.resize(n + 1)
	vertices[0] = 0
	breaks[0] = -1.0e20
	breaks[1] = 1.0e20
	var k: int = 0
	var square_spacing: float = spacing * spacing
	for q in range(1, n):
		var previous: int = vertices[k]
		var intersection: float = (input[q] - input[previous] + float(q * q - previous * previous) * square_spacing) / (2.0 * float(q - previous) * square_spacing)
		while intersection <= breaks[k] and k > 0:
			k -= 1
			previous = vertices[k]
			intersection = (input[q] - input[previous] + float(q * q - previous * previous) * square_spacing) / (2.0 * float(q - previous) * square_spacing)
		k += 1
		vertices[k] = q
		breaks[k] = intersection
		breaks[k + 1] = 1.0e20
	k = 0
	for q in range(n):
		while breaks[k + 1] < float(q):
			k += 1
		var delta: float = float(q - vertices[k]) * spacing
		result[q] = delta * delta + input[vertices[k]]
	return result


static func _emit_plane(tool: SurfaceTool, left: float, right: float, top: float, bottom: float) -> void:
	var points := [
		Vector3(left, SEA_HEIGHT, top), Vector3(right, SEA_HEIGHT, top),
		Vector3(right, SEA_HEIGHT, bottom), Vector3(left, SEA_HEIGHT, bottom)
	]
	for index in [0, 2, 1, 0, 3, 2]:
		var point: Vector3 = points[index]
		tool.set_uv(Vector2(point.x, point.z) * 0.22)
		tool.add_vertex(point)
