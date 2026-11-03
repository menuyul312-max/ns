extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	var unit: float = IslandDefinition.TILE_SIZE
	var center := Vector3(10.5 * unit, 0.0, 6.5 * unit)
	var channel_depth: float = RiverBathymetry.depth_at(island, center.x, center.z, 0)
	if channel_depth < 0.70 or channel_depth > 0.84:
		_fail("channel depression not deep enough: " + str(channel_depth))
		return
	var rules := WaterRules.new(island)
	var sample: Dictionary = rules.sample(center)
	if sample["zone"] != WaterRules.Zone.DEEP or absf(float(sample["depth"]) - channel_depth) > 0.001:
		_fail("gameplay depth disagrees with analytic riverbed")
		return
	var terrain := TerrainBuilder.build_world(island)
	root.add_child(terrain)
	await physics_frame
	await physics_frame
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3(0, 3, 0), center + Vector3(0, -4, 0), 1)
	var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		_fail("raycast missed dense ground mesh")
		return
	var expected: float = RiverBathymetry.floor_height_at(island, center.x, center.z, 0)
	if absf(float(hit["position"].y) - expected) > 0.045:
		_fail("physical ground diverges from analytic depth: %s vs %s" % [hit["position"].y, expected])
		return
	print("PASS — analytical channel depth %.2fm matches dense ground collider at %.2f" % [channel_depth, expected])
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
