extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Dictionary = IslandWaterValidator.audit(IslandDefinition.fixture_river())
	if fixture["water_tiles"] != 20 or fixture["components"] != 1 or fixture["waterfalls"] != 1 or fixture["steep_edges"] != 0:
		_fail("fixture should have one connected water network, one fall and no steep fall")
		return
	var sample := IslandDefinition.new(4, 4)
	sample.set_water(0, 0, true)
	sample.set_water(3, 3, true)
	var disconnected: Dictionary = IslandWaterValidator.audit(sample)
	if disconnected["components"] != 2 or disconnected["border_water_tiles"] != 2 or disconnected["notices"].is_empty():
		_fail("disconnected water components not detected")
		return
	sample.set_water(1, 0, true)
	sample.set_height(1, 0, 3)
	var steep: Dictionary = IslandWaterValidator.audit(sample)
	if steep["steep_edges"] != 1 or steep["waterfalls"] != 1:
		_fail("over-steep waterfall edge not detected")
		return
	print("PASS — layout audit detects connected rivers, separate ponds, steep falls and coast contact")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
