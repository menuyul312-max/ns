extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var first := IslandDefinition.fixture_terraces()
	var second := IslandDefinition.fixture_bend()
	var river := IslandDefinition.fixture_river()
	_assert_true(first.cliff_edge_count() > 0, "terraces expose cliffs")
	_assert_true(second.cliff_edge_count() > 0, "bend exposes cliffs")
	_assert_true(first.height_at(2, 2) == 2, "second level exists")
	_assert_true(first.height_at(-1, -1) == 0, "out of bounds is baseline")
	var rounded := TerrainBuilder._rounded_corners(1, [0, 0, 1, 1])
	_assert_true(rounded == [false, true, false, false], "matching-height corner can round")
	_assert_true(TerrainBuilder._rounded_corners(2, [0, 1, 2, 2])[1] == false, "mismatched wall heights keep sharp junction")
	var fraction: float = TerrainBuilder.CORNER_RADIUS / IslandDefinition.TILE_SIZE
	for corner in range(4):
		var arc_begin: Vector3 = TerrainBuilder._corner_arc_position(2, 3, corner, 0.0, 0.0, 1.55)
		var arc_end: Vector3 = TerrainBuilder._corner_arc_position(2, 3, corner, 1.0, 0.0, 1.55)
		var incoming: Vector3 = TerrainBuilder._edge_position(2, 3, (corner + 3) % 4, 1.0 - fraction, 0.0, 1.55)
		var outgoing: Vector3 = TerrainBuilder._edge_position(2, 3, corner, fraction, 0.0, 1.55)
		_assert_true(arc_begin.distance_to(incoming) < 0.0001, "rounded corner connects previous edge")
		_assert_true(arc_end.distance_to(outgoing) < 0.0001, "rounded corner connects next edge")
	var restored := IslandDefinition.from_dictionary(first.as_dictionary())
	_assert_true(restored.levels == first.levels, "serialization round-trip is lossless")
	var river_restored := IslandDefinition.from_dictionary(river.as_dictionary())
	_assert_true(river_restored.water == river.water, "water topology round-trip is lossless")
	var legacy_data: Dictionary = first.as_dictionary()
	legacy_data["schema_version"] = 1
	legacy_data.erase("water")
	var legacy_restored := IslandDefinition.from_dictionary(legacy_data)
	_assert_true(legacy_restored.water.count(1) == 0, "schema v1 terrain imports with an empty water layer")
	_assert_true(river.water.count(1) == 20, "river fixture has 20 wet tiles")
	_assert_true(river.waterfall_edge_count() == 1, "single cliff-to-river waterfall is found")
	var field := RiverContour.new(river)
	var unit: float = IslandDefinition.TILE_SIZE
	_assert_true(RiverContour.field_at(river, 10.5 * unit, 4.5 * unit, 0) > 0.95, "wet cell center is fully water")
	_assert_true(RiverContour.field_at(river, 12.5 * unit, 2.5 * unit, 0) < 0.05, "dry cell center stays outside water")
	var edge_value: float = RiverContour.field_at(river, 9.0 * unit, 8.5 * unit, 0)
	_assert_true(edge_value > 0.35 and edge_value < 0.65, "global shoreline crosses shared tile boundary")
	_assert_true(field.flow_at(Vector2(8.5 * unit, 3.5 * unit)).x > 0.5, "upper river points toward waterfall")
	for z in range(river.depth):
		for x in range(river.width):
			if river.is_water(x, z):
				river.set_height(x, z, 1)
	_assert_true(river.waterfall_edge_count() == 0, "all-same-height river has no waterfall")
	river = river_restored
	_assert_true(river.waterfall_edge_count() == 1, "waterfall returns when elevation breaks")
	# Adjacent cliff tiles must share exactly the same wall shape at their seam.
	for row in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_assert_true(is_equal_approx(TerrainBuilder._wall_offset(first, 1, 3, 0, 1.0, row), TerrainBuilder._wall_offset(first, 2, 3, 0, 0.0, row)), "north wall seam")
		_assert_true(is_equal_approx(TerrainBuilder._wall_offset(first, 3, 1, 1, 1.0, row), TerrainBuilder._wall_offset(first, 3, 2, 1, 0.0, row)), "east wall seam")
		_assert_true(is_equal_approx(TerrainBuilder._wall_offset(first, 2, 3, 2, 1.0, row), TerrainBuilder._wall_offset(first, 1, 3, 2, 0.0, row)), "south wall seam")
		_assert_true(is_equal_approx(TerrainBuilder._wall_offset(first, 3, 2, 3, 1.0, row), TerrainBuilder._wall_offset(first, 3, 1, 3, 0.0, row)), "west wall seam")
	for island in [first, second, river]:
		var world := TerrainBuilder.build_world(island)
		_assert_true(world.get_node_or_null("Ground") != null, "ground mesh exists")
		_assert_true(world.get_node_or_null("CliffFaces") != null, "cliff mesh exists")
		_assert_true(world.get_node_or_null("GrassLips") != null, "lip mesh exists")
		var grass_mesh: Mesh = world.get_node("GrassLips").mesh
		var grass_normals: PackedVector3Array = grass_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		for normal in grass_normals:
			_assert_true(normal.y > 0.9, "grass lips face upward")
		var ground_normals: PackedVector3Array = (world.get_node("Ground").mesh as Mesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var minimum_up: float = 0.25 if island.water.count(1) > 0 else 0.99
		for normal in ground_normals:
			_assert_true(normal.y > minimum_up, "ground slopes remain upward")
		var wall_normals: PackedVector3Array = (world.get_node("CliffFaces").mesh as Mesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		_assert_true(wall_normals[0].z < -0.8, "north wall faces outward")
		var collider: StaticBody3D = world.get_node("WorldCollision")
		_assert_true(collider.get_child_count() == 2, "terrain meshes have collision")
		world.free()
	var river_root := WaterBuilder.build_world(river)
	_assert_true(river_root.get_node_or_null("WaterSurface") != null, "water mesh exists")
	_assert_true(river_root.get_node_or_null("RiverBanks") != null, "bank mesh exists")
	_assert_true(river_root.get_node_or_null("ShoreFoam") != null, "shore foam mesh exists")
	_assert_true(river_root.get_node_or_null("Waterfalls") != null, "waterfall mesh exists")
	_assert_true(river_root.get_node_or_null("FallFoam") != null, "fall foam mesh exists")
	_assert_true(river_root.get_node_or_null("RiverBankCollision") != null, "bank mesh provides real collision")
	_assert_true(river_root.get_node("WaterTriggers").get_child_count() == 20, "water area triggers follow topology")
	var water_normals: PackedVector3Array = (river_root.get_node("WaterSurface").mesh as Mesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in water_normals:
		_assert_true(normal.y > 0.85, "water surface normal faces up")
	river_root.free()
	if failures.is_empty():
		print("PASS — 3 fixtures, water topology, waterfall mesh, bank foam, normals, collision, serialization")
		quit(0)
	else:
		push_error("FAIL — " + ", ".join(failures))
		quit(1)


func _assert_true(value: bool, context: String) -> void:
	if not value:
		if not failures.has(context):
			failures.append(context)
