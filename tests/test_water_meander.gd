extends SceneTree
## Sprint 18 regression: world-continuous meandering banks and water mesh.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(12, 12)
	for z in range(12):
		for x in range(4, 7):
			island.set_water(x, z, true)
	var minimum: float = 999.0
	var maximum: float = -999.0
	for i in range(68):
		var wz: float = (float(i) + 3.0) / 7.0 * IslandDefinition.TILE_SIZE
		var bank_x: float = _crossing_x(island, wz)
		minimum = minf(minimum, bank_x)
		maximum = maxf(maximum, bank_x)
		var field_a: float = RiverContour.field_at(island, 4.0 * IslandDefinition.TILE_SIZE - 0.0001, wz, 0)
		var field_b: float = RiverContour.field_at(island, 4.0 * IslandDefinition.TILE_SIZE + 0.0001, wz, 0)
		if absf(field_a - field_b) > 0.002:
			_fail("scalar water field broke across tile boundary")
			return
	if maximum - minimum < 0.13:
		_fail("long shoreline did not meander enough: %.3f" % (maximum - minimum))
		return
	var core: float = RiverContour.field_at(island, 5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE, 0)
	var dry: float = RiverContour.field_at(island, 2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE, 0)
	if core < RiverContour.THRESHOLD or dry >= RiverContour.THRESHOLD:
		_fail("domain warp incorrectly changed wet/dry interior")
		return
	if WaterBuilder.WATER_SHADER.contains("flow_direction * 0.16") or not WaterBuilder.WATER_SHADER.contains("fbm"):
		_fail("water shader regressed to interpolated flow UV seam")
		return
	var water_root := WaterBuilder.build_world(island)
	if water_root.get_node_or_null("WaterSurface") == null or water_root.get_node_or_null("RiverBanks") == null or water_root.get_node_or_null("RiverBankCollision") == null:
		_fail("water, shared shoreline and bank collider must be generated")
		return
	water_root.free()
	print("PASS — smooth shared meander %.3f units, wet core, banks, and coherent water shader" % (maximum - minimum))
	quit(0)


func _crossing_x(island: IslandDefinition, wz: float) -> float:
	var lo: float = 3.5 * IslandDefinition.TILE_SIZE
	var hi: float = 4.5 * IslandDefinition.TILE_SIZE
	for _i in range(26):
		var mid: float = (lo + hi) * 0.5
		if RiverContour.field_at(island, mid, wz, 0) < RiverContour.THRESHOLD:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
