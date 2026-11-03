class_name IslandLinkBuilder
extends RefCounted
## Original low-poly connector surfaces, with actual static trimesh colliders.
## These materials/measurements are a lab design, not Nintendo extraction.

const DECK_WIDTH: float = 1.66
const SLICES: int = 12


static func build_world(island: IslandDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "NusantaraConnectors"
	for z in range(island.depth):
		for x in range(island.width):
			var kind: int = island.connector_at(x, z)
			if kind == 0 or not IslandLinkRules.is_valid(island, x, z, kind):
				continue
			var span: Dictionary = {}
			if IslandLinkRules.is_bridge_kind(kind):
				span = IslandLinkRules.bridge_span(island, x, z, kind, true)
				if Vector2i(x, z) != span["first"]:
					continue
			root.add_child(_build_one(island, x, z, kind, span))
	return root


static func _build_one(island: IslandDefinition, x: int, z: int, kind: int, span: Dictionary = {}) -> StaticBody3D:
	var ramp: bool = kind >= 1 and kind <= 4
	var direction: Vector2i = IslandLinkRules.direction_for_ramp(kind) if ramp else (Vector2i.RIGHT if kind == 5 else Vector2i.DOWN)
	var forward := Vector3(float(direction.x), 0.0, float(direction.y))
	var side := Vector3(-forward.z, 0.0, forward.x)
	var size: float = IslandDefinition.TILE_SIZE
	var bridge_count: int = 1 if ramp else (span["cells"] as Array).size()
	var length: float = size if ramp else size * (float(bridge_count) + 0.28)
	var base_y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP
	var center := Vector3((float(x) + 0.5) * size, base_y, (float(z) + 0.5) * size)
	if not ramp:
		var last: Vector2i = span["last"]
		center.x = (float(x + last.x) * 0.5 + 0.5) * size
		center.z = (float(z + last.y) * 0.5 + 0.5) * size
	var slices: int = SLICES * bridge_count
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(slices):
		var a: float = float(segment) / float(slices)
		var b: float = float(segment + 1) / float(slices)
		var ha: float = _surface_height(a, ramp)
		var hb: float = _surface_height(b, ramp)
		var start := center + forward * ((a - 0.5) * length) + Vector3.UP * ha
		var end := center + forward * ((b - 0.5) * length) + Vector3.UP * hb
		var left_start: Vector3 = start - side * (DECK_WIDTH * 0.5)
		var right_start: Vector3 = start + side * (DECK_WIDTH * 0.5)
		var left_end: Vector3 = end - side * (DECK_WIDTH * 0.5)
		var right_end: Vector3 = end + side * (DECK_WIDTH * 0.5)
		for vertex in [left_start, right_end, left_end, left_start, right_start, right_end]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var surface: ArrayMesh = tool.commit()
	var body := StaticBody3D.new()
	body.name = ("Ramp" if ramp else "Bridge") + "_%d_%d" % [x, z]
	# Connector layer 32: distinct from props (16), editor selection (1), feet detail (8).
	body.collision_layer = 32
	body.collision_mask = 0
	var visual := MeshInstance3D.new()
	visual.name = "WalkDeck"
	visual.mesh = surface
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.37, 0.19) if ramp else Color(0.77, 0.51, 0.27)
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "DeckCollision"
	var shape: ConcavePolygonShape3D = surface.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	# All planks, side beams and piers are visual-only; the smooth continuous
	# triangulated deck above remains the sole traversable collider.
	_add_joinery(body, center, forward, side, length, ramp, slices)
	if not ramp:
		_add_bank_aprons(body, island, center, forward, side, bridge_count, base_y)
	# Short entrance posts guide the capsule without a waist-height barrier.
	for t in [0.16, 0.84]:
		for s in [-1.0, 1.0]:
			var anchor: Vector3 = center + forward * ((float(t) - 0.5) * length) + side * float(s) * (DECK_WIDTH * 0.57)
			anchor.y += _surface_height(t, ramp) + 0.18
			var stake := CylinderMesh.new()
			stake.top_radius = 0.045
			stake.bottom_radius = 0.065
			stake.height = 0.36
			_add_piece(body, "PenandaKayu", stake, anchor, Color(0.35, 0.22, 0.13))
	return body


static func _add_joinery(body: StaticBody3D, center: Vector3, forward: Vector3, side: Vector3, length: float, ramp: bool, slices: int) -> void:
	var step: float = length / float(slices)
	for segment in range(slices):
		var a: float = float(segment) / float(slices)
		var b: float = float(segment + 1) / float(slices)
		var t: float = (a + b) * 0.5
		var pitch: float = atan2(_surface_height(b, ramp) - _surface_height(a, ramp), step)
		var origin: Vector3 = center + forward * ((t - 0.5) * length) + Vector3.UP * (_surface_height(t, ramp) + 0.029)
		var slat := BoxMesh.new()
		var slat_length: float = step * 0.91
		slat.size = Vector3(slat_length if absf(forward.x) > 0.5 else DECK_WIDTH * 0.91, 0.035, DECK_WIDTH * 0.91 if absf(forward.x) > 0.5 else slat_length)
		var tone: Color = Color(0.60, 0.33, 0.16) if ramp else Color(0.83, 0.64, 0.30)
		if segment % 3 == 1:
			tone = tone.darkened(0.10)
		elif segment % 3 == 2:
			tone = tone.lightened(0.065)
		var board: MeshInstance3D = _add_piece(body, "BilahKayu_%02d" % segment, slat, origin, tone)
		_tilt(board, forward, pitch)
		for direction in [-1.0, 1.0]:
			var beam := BoxMesh.new()
			beam.size = Vector3(step * 0.98 if absf(forward.x) > 0.5 else 0.082, 0.085, 0.082 if absf(forward.x) > 0.5 else step * 0.98)
			var beam_center: Vector3 = origin + side * (float(direction) * DECK_WIDTH * 0.51) + Vector3.UP * 0.055
			var railing: MeshInstance3D = _add_piece(body, "BibirKayu", beam, beam_center, Color(0.36, 0.21, 0.12) if ramp else Color(0.46, 0.34, 0.17))
			_tilt(railing, forward, pitch)
	if not ramp:
		# Four visible bamboo piles sink below the waterline and break the flat silhouette.
		for t in [0.27, 0.73]:
			for direction in [-1.0, 1.0]:
				var pile := CylinderMesh.new()
				pile.top_radius = 0.08
				pile.bottom_radius = 0.105
				pile.height = 1.05
				var pile_base: Vector3 = center + forward * ((float(t) - 0.5) * length) + side * (float(direction) * DECK_WIDTH * 0.57)
				pile_base.y += _surface_height(t, false) - 0.42
				_add_piece(body, "TiangBambu", pile, pile_base, Color(0.49, 0.38, 0.18))


static func _add_bank_aprons(body: StaticBody3D, island: IslandDefinition, center: Vector3, forward: Vector3, side: Vector3, span_count: int, base_y: float) -> void:
	# Soft, scalloped sand-to-deck transitions. Render-only; actual floor remains terrain.
	var size: float = IslandDefinition.TILE_SIZE
	var bank_distance: float = float(span_count) * size * 0.5
	for end_sign in [-1.0, 1.0]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(12):
			var u0: float = float(segment) / 6.0 - 1.0
			var u1: float = float(segment + 1) / 6.0 - 1.0
			var inner0: Vector3 = _apron_point(center, forward, side, bank_distance, size, u0, end_sign, false)
			var inner1: Vector3 = _apron_point(center, forward, side, bank_distance, size, u1, end_sign, false)
			var outer0: Vector3 = _apron_point(center, forward, side, bank_distance, size, u0, end_sign, true)
			var outer1: Vector3 = _apron_point(center, forward, side, bank_distance, size, u1, end_sign, true)
			var vertices: Array[Vector3] = [inner0, outer0, outer1, inner0, outer1, inner1]
			for vertex_index in range(vertices.size()):
				var point: Vector3 = vertices[vertex_index]
				point.y = RiverBathymetry.floor_height_at(island, point.x, point.z, roundi(base_y / IslandDefinition.HEIGHT_STEP)) + 0.047
				var opacity: float = 0.0 if vertex_index in [1, 2, 4] else 0.63
				tool.set_color(Color(0.75, 0.57, 0.37, opacity))
				tool.add_vertex(point)
		tool.generate_normals()
		var apron := MeshInstance3D.new()
		apron.name = "BankApronA" if end_sign < 0.0 else "BankApronB"
		apron.mesh = tool.commit()
		var sand := StandardMaterial3D.new()
		sand.albedo_color = Color.WHITE
		sand.vertex_color_use_as_albedo = true
		sand.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sand.cull_mode = BaseMaterial3D.CULL_DISABLED
		sand.roughness = 1.0
		apron.material_override = sand
		apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(apron)
		# Two softened stones each side hide the angular start of the hand-built deck.
		for shore_side in [-1.0, 1.0]:
			for row in range(2):
				var small_stone := SphereMesh.new()
				small_stone.radius = 0.092 + 0.014 * float(row)
				small_stone.height = 0.085
				var pos: Vector3 = center + forward * (float(end_sign) * (bank_distance + size * (0.14 + 0.17 * float(row)))) + side * (shore_side * (DECK_WIDTH * 0.57 + 0.06 * float(row)))
				pos.y = RiverBathymetry.floor_height_at(island, pos.x, pos.z, roundi(base_y / IslandDefinition.HEIGHT_STEP)) + 0.043
				_add_piece(body, "BatuTepi", small_stone, pos, Color(0.24, 0.25, 0.22) if row == 0 else Color(0.36, 0.31, 0.24))


static func _apron_point(center: Vector3, forward: Vector3, side: Vector3, bank_distance: float, size: float, u: float, end_sign: float, outer: bool) -> Vector3:
	var wave: float = 0.075 * sin(u * 5.0 + end_sign * 1.2) + 0.035 * cos(u * 8.0)
	var landward: float = size * (0.31 + 0.15 * (1.0 - u * u) + wave) if outer else size * 0.017
	var breadth: float = DECK_WIDTH * (0.63 if outer else 0.51)
	return center + forward * (end_sign * (bank_distance + landward)) + side * (u * breadth)


static func _tilt(item: MeshInstance3D, forward: Vector3, angle: float) -> void:
	if absf(forward.x) > 0.5:
		item.rotation.z = angle * signf(forward.x)
	else:
		item.rotation.x = -angle * signf(forward.z)


static func _surface_height(t: float, ramp: bool) -> float:
	return (0.018 + IslandDefinition.HEIGHT_STEP * t) if ramp else (-0.035 + 0.26 * sin(PI * t))


static func _add_piece(parent: Node3D, label: String, mesh: Mesh, offset: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.position = offset
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.98
	item.material_override = material
	parent.add_child(item)
	return item
