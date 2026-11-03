extends SceneTree
## A small deterministic coast should not introduce cracks at tile boundaries.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(16, 10)
	var tile: float = IslandDefinition.TILE_SIZE
	var bounds: float = float(island.width) * tile
	var displacement_min: float = 999.0
	var displacement_max: float = -999.0
	for i in range(160):
		var x: float = float(i) / 159.0 * bounds
		var original := Vector3(x, 0.0, 0.0)
		var warped: Vector3 = CoastContour.warp_ground(island, original, 0)
		var amount: float = warped.z - original.z
		displacement_min = minf(displacement_min, amount)
		displacement_max = maxf(displacement_max, amount)
		if not is_finite(warped.x) or not is_finite(warped.z):
			_fail("invalid coast world-space coordinates")
			return
	if displacement_max - displacement_min < 0.31:
		_fail("coast outline remains too straight: %.3f" % (displacement_max - displacement_min))
		return
	for edge in range(1, 15):
		var left: Vector3 = CoastContour.warp_ground(island, Vector3(float(edge) * tile - 0.0001, 0, 0), 0)
		var right: Vector3 = CoastContour.warp_ground(island, Vector3(float(edge) * tile + 0.0001, 0, 0), 0)
		if left.distance_to(right) > 0.006:
			_fail("coastline jumped across cell boundary at %d" % edge)
			return
	var inland := Vector3(6.0 * tile, 0, 4.0 * tile)
	if CoastContour.warp_ground(island, inland, 0).distance_to(inland) > 0.00001:
		_fail("coast modifier touched the interior plateau")
		return
	if not CoastContour.on_island(island, inland.x, inland.z):
		_fail("interior ground was rejected by coastal movement boundary")
		return
	var dry_cove := false
	for i in range(100):
		var px: float = (float(i) + 0.5) / 100.0 * bounds
		var nx: float = CoastContour.warp_ground(island, Vector3(px, 0.0, 0.0), 0).z
		if nx > 0.08 and not CoastContour.on_island(island, px, 0.015):
			dry_cove = true
			break
	if not dry_cove:
		_fail("movement boundary did not reject an exposed coastline cove")
		return
	for z in range(3):
		for x in range(4, 7):
			island.set_water(x, z, true)
	var mouth := Vector3(5.5 * tile, 0, 0)
	if CoastContour.warp_ground(island, mouth, 0).distance_to(mouth) > 0.00001:
		_fail("river mouth must remain aligned with the ocean outlet")
		return
	var land := TerrainBuilder.build_world(island)
	if land.get_node_or_null("WorldCollision") == null or land.get_node_or_null("Ground") == null:
		_fail("deformed beach lost real terrain collider")
		return
	var sea := CoastBuilder.build_world(island)
	if sea.get_node_or_null("OceanSurface") == null:
		_fail("coastal ocean did not extend behind the cove relief")
		return
	var hydrology := WaterBuilder.build_world(island)
	var surface: MeshInstance3D = hydrology.get_node_or_null("WaterSurface")
	var water_colors: PackedColorArray = surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var smallest: float = 1.0
	var largest: float = 0.0
	for color in water_colors:
		smallest = minf(smallest, color.a)
		largest = maxf(largest, color.a)
	if smallest > 0.22 or largest < 0.90:
		_fail("river-to-sea opacity ramp missing: %.2f..%.2f" % [smallest, largest])
		return
	land.free()
	sea.free()
	hydrology.free()
	print("PASS — coast bend %.3f, continuous seams, movement boundary, ocean and river opacity %.2f..%.2f" % [displacement_max - displacement_min, smallest, largest])
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
