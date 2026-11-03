extends SceneTree
## Sprint 26–28 acceptance: mask topology, ocean SDF, gameplay and legacy data.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(7, 7)
	var composer := IslandComposer.new(island)
	if not composer.set_land_presence(3, 3, false):
		_fail("topological edit refused a clear, low, dry tile")
		return
	if island.is_land(3, 3) or island.land_mask.count(0) != 1:
		_fail("removed tile is still marked as playable land")
		return
	if IslandLinkRules.is_walk_node(island, Vector2i(3, 3)):
		_fail("access graph still contains a submerged tile")
		return
	var movement := WaterRules.new(island)
	var unit: float = IslandDefinition.TILE_SIZE
	if movement.can_traverse_path(Vector3(2.5 * unit, 0.0, 3.5 * unit), Vector3(3.5 * unit, 0.0, 3.5 * unit), WaterRules.Mode.SWIM):
		_fail("swimming actor traversed the unimplemented open ocean")
		return
	var land_world := TerrainBuilder.build_world(island)
	if land_world.get_node_or_null("WorldCollision") == null or land_world.get_node_or_null("MaskedShoreSkirts") == null:
		_fail("coast masks lost real collider or sandy skirt geometry")
		return
	var ocean := CoastBuilder.build_world(island)
	var ocean_mesh: MeshInstance3D = ocean.get_node_or_null("OceanSurface")
	var shader_material: ShaderMaterial = ocean_mesh.material_override
	if float(shader_material.get_shader_parameter("use_coast_sdf")) < 0.99:
		_fail("masked coast did not activate signed-distance foam")
		return
	var sdf: Image = CoastBuilder.make_signed_coast_texture(island).get_image()
	var hole: float = _read_sdf(sdf, island, 3.5 * unit, 3.5 * unit)
	var land: float = _read_sdf(sdf, island, 1.5 * unit, 1.5 * unit)
	if hole < 0.10 or land > -0.10:
		_fail("ocean SDF does not distinguish deleted coast %.2f from land %.2f" % [hole, land])
		return
	land_world.free()
	ocean.free()
	var saved: Dictionary = island.as_dictionary()
	if int(saved["schema_version"]) != 7 or int(saved["land_mask"][3 * island.width + 3]) != 0:
		_fail("mask was not serialized in schema v7")
		return
	var copy: IslandDefinition = IslandDefinition.from_dictionary(saved)
	if copy.is_land(3, 3):
		_fail("schema v7 restore recreated an ocean cell as ground")
		return
	var legacy: Dictionary = saved.duplicate(true)
	legacy["schema_version"] = 6
	legacy.erase("land_mask")
	var older: IslandDefinition = IslandDefinition.from_dictionary(legacy)
	if not older.is_land(3, 3):
		_fail("v6 migration failed to initialize a solid legacy land map")
		return
	if not composer.set_land_presence(3, 3, true) or not island.is_land(3, 3):
		_fail("topology editor cannot refill previously removed ground")
		return
	island.set_occupant(3, 3, 1)
	if composer.set_land_presence(3, 3, false) or composer.last_edit_report.get("code") != "MASK_OCCUPIED":
		_fail("topology editor removed an occupied land cell")
		return
	var protected := IslandComposer.new(IslandDefinition.new(3, 1))
	protected.protect_connectivity = true
	if protected.set_land_presence(1, 0, false) or protected.last_edit_report.get("code") != "MASK_ACCESS_SPLIT":
		_fail("connectivity guard allowed the only walkable bridge tile to vanish")
		return
	var river := IslandDefinition.new(7, 7)
	river.set_water(3, 3, true)
	river.set_land(3, 4, false)
	if RiverContour._occupancy(river, 3, 4, 0) < 0.6:
		_fail("river cell did not connect to newly authored sea outlet")
		return
	var fixture: IslandDefinition = IslandDefinition.fixture_coast_mask()
	if fixture.land_mask.count(0) < 18 or fixture.land_mask.count(1) < 60 or fixture.water.count(1) < 3:
		_fail("free-shape reference layout became empty or rectangular")
		return
	print("PASS — topology save v7, ocean SDF, real ground collision, shore skirt, protected edit, river mouth")
	quit(0)


func _read_sdf(image: Image, island: IslandDefinition, x: float, z: float) -> float:
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE + 2.0 * CoastBuilder.SEA_MARGIN
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE + 2.0 * CoastBuilder.SEA_MARGIN
	var u: int = roundi((x + CoastBuilder.SEA_MARGIN) / w * float(image.get_width() - 1))
	var v: int = roundi((z + CoastBuilder.SEA_MARGIN) / d * float(image.get_height() - 1))
	return image.get_pixel(u, v).r


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
