extends SceneTree
## Sprint 23–24 acceptance: coast editor, shader boundary, persistence, legacy.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(16, 10)
	var tile: float = IslandDefinition.TILE_SIZE
	var shore_z: float = 4.0 * tile
	var before: float = CoastContour.boundary_at(island, 0, shore_z)
	var composer := IslandComposer.new(island)
	if not composer.sculpt_coast(0, 4, 0.60) or not composer.sculpt_coast(0, 5, 0.60):
		_fail("coast sculpt control refused valid neighboring nodes")
		return
	if not composer.sculpt_coast(2, 8, 0.80):
		_fail("north coast sculpt refused a valid node")
		return
	if composer.sculpt_coast(0, 0, 0.2):
		_fail("corner endpoints must stay pinned")
		return
	if CoastContour.boundary_at(island, 0, shore_z) < before + 0.55:
		_fail("editing the shore did not move its real ground edge")
		return
	for i in range(1, 15):
		var one: float = CoastContour.boundary_at(island, 0, (float(i) - 0.0001) * tile)
		var two: float = CoastContour.boundary_at(island, 0, (float(i) + 0.0001) * tile)
		if absf(one - two) > 0.006:
			_fail("coastal spline cracked at tile %d" % i)
			return
	var texture: ImageTexture = CoastBuilder.make_shoreline_texture(island)
	var pixels: Image = texture.get_image()
	if pixels.get_width() != CoastBuilder.PROFILE_SAMPLES:
		_fail("shoreline LUT resolution differs from declared format")
		return
	for side in range(4):
		var length: float = float(island.depth if side < 2 else island.width) * tile
		for probe in [0.0, 0.14, 0.42, 0.57, 0.83, 1.0]:
			var index: int = roundi(probe * float(CoastBuilder.PROFILE_SAMPLES - 1))
			var fraction: float = float(index) / float(CoastBuilder.PROFILE_SAMPLES - 1)
			var pixel: Color = pixels.get_pixel(index, 0)
			var baked: float = [pixel.r, pixel.g, pixel.b, pixel.a][side]
			var exact: float = CoastContour.boundary_at(island, side, fraction * length)
			if absf(baked - exact) > 0.004:
				_fail("ocean wave LUT diverged from collision contour: side %d" % side)
				return
	var west: float = CoastContour.boundary_at(island, 0, shore_z)
	if CoastContour.on_island(island, west - 0.04, shore_z) or not CoastContour.on_island(island, west + 0.07, shore_z):
		_fail("movement test and authorable coastline disagree")
		return
	var save: Dictionary = island.as_dictionary()
	var restored := IslandDefinition.from_dictionary(save)
	if save["schema_version"] != 7 or absf(restored.coast_inset_at(0, shore_z) - 0.60) > 0.005:
		_fail("coast samples were not preserved in schema v7")
		return
	var legacy: Dictionary = save.duplicate(true)
	legacy["schema_version"] = 5
	legacy.erase("shore_profiles")
	var migrated := IslandDefinition.from_dictionary(legacy)
	if not is_zero_approx(migrated.coast_inset_at(0, shore_z)):
		_fail("schema v5 migration did not restore neutral coast shape")
		return
	var outlet := IslandDefinition.new(16, 10)
	for z in range(3):
		for x in range(4, 7):
			outlet.set_water(x, z, true)
	outlet.set_coast_inset(2, 5, 1.10)
	var mouth: Vector3 = Vector3(5.5 * tile, 0.0, 0.0)
	if CoastContour.warp_ground(outlet, mouth, 0).distance_to(mouth) > 0.01:
		_fail("authored coast inset blocked a freshwater ocean outlet")
		return
	var terrain: Node3D = TerrainBuilder.build_world(island)
	var sea: Node3D = CoastBuilder.build_world(island)
	if terrain.get_node_or_null("WorldCollision") == null or sea.get_node_or_null("OceanSurface") == null:
		_fail("shore sculpt broke collision or ocean world")
		return
	terrain.free()
	sea.free()
	print("PASS — authorable spline coast, LUT/collision agreement, movement, schema v7+v5 migration")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
