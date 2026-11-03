extends SceneTree
## Global coastline topology; open-world mesh/collision still use old builder.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rectangle := IslandDefinition.new(4, 4)
	var first: Dictionary = IslandCoastLoops.trace(rectangle)
	if first["islands"] != 1 or first["holes"] != 0 or first["broken_chains"] != 0 or first["boundary_edges"] != 16:
		_fail("simple 4x4 rectangle did not yield a closed outer boundary")
		return
	if not _assert_area(rectangle, first, "rectangle"):
		return
	rectangle.set_land(1, 1, false)
	var with_lake: Dictionary = IslandCoastLoops.trace(rectangle)
	if with_lake["islands"] != 1 or with_lake["holes"] != 1 or with_lake["broken_chains"] != 0:
		_fail("enclosed water hole did not get an oppositely oriented ring")
		return
	if not _assert_area(rectangle, with_lake, "internal hole"):
		return
	var diagonal := IslandDefinition.new(2, 2)
	diagonal.set_land(1, 0, false)
	diagonal.set_land(0, 1, false)
	var touching: Dictionary = IslandCoastLoops.trace(diagonal)
	if touching["islands"] != 2 or touching["holes"] != 0 or touching["broken_chains"] != 0:
		_fail("diagonal corner contact must not merge independent islets")
		return
	if not _assert_area(diagonal, touching, "diagonal islets"):
		return
	var fixture := IslandDefinition.fixture_coast_mask()
	var coastline: Dictionary = IslandCoastLoops.trace(fixture)
	if coastline["islands"] < 2 or coastline["broken_chains"] != 0:
		_fail("coast fixture lost its separate sandbar or has open chains")
		return
	if not _assert_area(fixture, coastline, "coast fixture"):
		return
	print("PASS — closed multi-rings; interior hole; diagonal islands; signed area conservation")
	quit(0)


func _assert_area(island: IslandDefinition, result: Dictionary, label: String) -> bool:
	var expected: float = float(island.land_mask.count(1)) * IslandDefinition.TILE_SIZE * IslandDefinition.TILE_SIZE
	if absf(float(result["signed_area_world"]) - expected) > 0.001:
		_fail("%s area mismatch: %.3f vs %.3f" % [label, result["signed_area_world"], expected])
		return false
	return true


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
