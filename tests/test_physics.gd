extends SceneTree


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var world := TerrainBuilder.build_world(IslandDefinition.fixture_terraces())
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var tile: float = IslandDefinition.TILE_SIZE
	var upper: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.5 * tile, 10.0, 2.5 * tile), Vector3(2.5 * tile, -3.0, 2.5 * tile)))
	var beach: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.5 * tile, 10.0, 0.5 * tile), Vector3(0.5 * tile, -3.0, 0.5 * tile)))
	var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.5 * tile, 0.70, 0.25 * tile), Vector3(2.5 * tile, 0.70, 2.5 * tile)))
	var failures: Array[String] = []
	if upper.is_empty() or not is_equal_approx(upper["position"].y, 2.0 * IslandDefinition.HEIGHT_STEP):
		failures.append("raycast did not hit the upper terrace")
	if beach.is_empty() or not is_equal_approx(beach["position"].y, 0.0):
		failures.append("raycast did not hit the beach baseline")
	if wall.is_empty() or wall["position"].z > tile:
		failures.append("horizontal ray penetrated the first cliff wall")
	if not failures.is_empty():
		push_error("FAIL — " + ", ".join(failures))
		quit(1)
		return
	print("PASS — physics raycasts hit beach, elevated ground, and cliff wall")
	quit(0)
