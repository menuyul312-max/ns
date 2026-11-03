extends SceneTree
## RiverContour supplies precise water classification; bank surface has collision.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	var field := RiverContour.new(island)
	var unit: float = IslandDefinition.TILE_SIZE
	if not field.contains_water(Vector3(10.5 * unit, -0.08, 4.5 * unit)):
		_fail("center of low river not classified as water")
		return
	if field.contains_water(Vector3(12.5 * unit, -0.08, 2.5 * unit)):
		_fail("dry patch incorrectly classified as water")
		return
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			var direction: Vector2 = field.flow_dirs[z * island.width + x]
			if direction == Vector2.ZERO:
				continue
			var next_x: int = x + roundi(direction.x)
			var next_z: int = z + roundi(direction.y)
			if not island.is_water(next_x, next_z) or island.height_at(next_x, next_z) > island.height_at(x, z):
				_fail("flow direction points uphill or outside river")
				return
	var hydrology := WaterBuilder.build_world(island)
	root.add_child(hydrology)
	await physics_frame
	await physics_frame
	var bank: StaticBody3D = hydrology.get_node("RiverBankCollision")
	var space: PhysicsDirectSpaceState3D = hydrology.get_world_3d().direct_space_state
	var ray_start := Vector3(9.0 * unit - 0.09, 4.0, 8.5 * unit)
	var ray_end := ray_start + Vector3(0.0, -6.0, 0.0)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_end))
	if hit.is_empty() or hit["collider"] != bank:
		_fail("raycast did not hit bank collider")
		return
	print("PASS — global water query, downhill flow directions, and actual bank raycast")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
