extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(3, 3)
	var flat: Dictionary = TerrainRegionDiagnostic.evaluate(island, 0)
	if flat["counts"] != PackedInt32Array([0, 0, 9, 0]):
		_fail("flat synthetic regions should pass")
		return
	island.set_water(1, 1, true)
	var base_only: Dictionary = TerrainRegionDiagnostic.evaluate(island, 1)
	var active_overlay: Dictionary = TerrainRegionDiagnostic.evaluate(island, 0)
	if base_only["counts"] != PackedInt32Array([0, 1, 8, 0]):
		_fail("mode 1 should ignore synthetic water overlay")
		return
	if active_overlay["counts"] != PackedInt32Array([0, 1, 0, 8]):
		_fail("mode 0 should detect +0.16 synthetic overlay in 3x3")
		return
	island.set_water(1, 1, false)
	island.set_height(1, 1, 1)
	var slope: Dictionary = TerrainRegionDiagnostic.evaluate(island, 0)
	if slope["counts"] != PackedInt32Array([0, 0, 0, 9]):
		_fail("height spread should reject 3x3 touching a terrace")
		return
	island.set_land(0, 0, false)
	var removed: Dictionary = TerrainRegionDiagnostic.evaluate(island, 0)
	if removed["statuses"][0] != 0 or removed["counts"][0] != 1:
		_fail("deleted land must not render as terrain")
		return
	print("PASS — Sprint48 synthetic diagnostic projection, height/overlay modes, missing land")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
