extends SceneTree
## Sprint 33: real ground mesh+collider and analytical traversability use
## the same curved triangles in missing-mask reentrant corners.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe_edt: PackedFloat32Array = CoastBuilder._edt_1d(PackedFloat32Array([100000.0, 100000.0, 0.0, 100000.0, 100000.0]), 2.0)
	var squared: Array[float] = [16.0, 4.0, 0.0, 4.0, 16.0]
	for index in range(squared.size()):
		if absf(probe_edt[index] - squared[index]) > 0.0001:
			_fail("exact coast EDT failed anisotropic sample %d: %f" % [index, probe_edt[index]])
			return
	var island := IslandDefinition.new(6, 6)
	island.set_land(3, 3, false)
	for corner in range(4):
		if not TerrainBuilder._is_concave_mask_corner(island, 3, 3, corner):
			_fail("surrounded missing cell did not expose four reentrant corners")
			return
	var size: float = IslandDefinition.TILE_SIZE
	var near_corner := Vector2(3.0 * size + 0.045, 3.0 * size + 0.045)
	var center := Vector2(3.5 * size, 3.5 * size)
	if not TerrainBuilder.on_concave_fillet(island, 3, 3, 0, near_corner):
		_fail("geometrically curved shoreline cap is not pickable")
		return
	if not CoastContour.on_island(island, near_corner.x, near_corner.y):
		_fail("movement gate disagrees with collidable fillet")
		return
	if CoastContour.on_island(island, center.x, center.y):
		_fail("concave fillet accidentally filled the entire ocean cell")
		return
	var terrain: Node3D = TerrainBuilder.build_world(island)
	var ground: MeshInstance3D = terrain.get_node_or_null("Ground")
	var body: StaticBody3D = terrain.get_node_or_null("WorldCollision")
	if ground == null or body == null or body.get_child_count() < 1:
		_fail("cap not included in the authoritative ground collision mesh")
		return
	var has_fillet_vertex: bool = false
	var vertices: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in vertices:
		if p.x > 3.0 * size + 0.02 and p.x < 3.0 * size + TerrainBuilder.INLET_FILLET_RADIUS and p.z > 3.0 * size + 0.02 and p.z < 3.0 * size + TerrainBuilder.INLET_FILLET_RADIUS:
			has_fillet_vertex = true
			break
	if not has_fillet_vertex:
		_fail("ground mesh did not fill the rounded inlet inside a deleted tile")
		return
	terrain.free()
	# A shoreline touching a river is deliberately not rounded across the wet
	# channel; the patch must not create an accidental over-water bridge.
	island.set_water(2, 3, true)
	if TerrainBuilder._is_concave_mask_corner(island, 3, 3, 0):
		_fail("reentrant patch bridged across an active river")
		return
	print("PASS — exact distance transform, concave shoreline fill, movement gate, real collision, no river bridge")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
