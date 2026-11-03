extends SceneTree
## Real-engine regression for an island's warped OUTER boundary.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(14, 14)
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var witnessed: int = 0
	for i in range(1, 56):
		var z: float = d * float(i) / 56.0
		var west: float = CoastContour.boundary_at(island, 0, z)
		if west < -0.08:
			if not CoastContour.on_island(island, west + 0.04, z):
				_fail("outward west coast is missing from land mask")
				return
			if CoastContour.on_island(island, west - 0.10, z):
				_fail("water beyond west warped coast marked as land")
				return
			witnessed += 1
		var east: float = CoastContour.boundary_at(island, 1, z)
		if east > w + 0.08:
			if not CoastContour.on_island(island, east - 0.04, z):
				_fail("outward east coast is missing from land mask")
				return
			if CoastContour.on_island(island, east + 0.10, z):
				_fail("water beyond east warped coast marked as land")
				return
			witnessed += 1
	if witnessed < 1:
		_fail("fixture did not exercise any outward coast wave")
		return
	if CoastContour.on_island(island, -CoastContour.OUTER_WARP_GUARD - 1.0, d * 0.5):
		_fail("remote ocean accepted beyond guard")
		return
	print("PASS — outer warped shore masks align with actual displaced boundary (%s probes)" % witnessed)
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
