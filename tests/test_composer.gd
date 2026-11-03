extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var composer := IslandComposer.new()
	var before: int = composer.island.height_at(2, 2)
	if not composer.modify_tile(2, 2, 1) or composer.island.height_at(2, 2) != before + 1:
		_fail("raise brush did not update elevation")
		return
	if not composer.modify_tile(2, 2, -1) or composer.island.height_at(2, 2) != before:
		_fail("lower brush did not restore elevation")
		return
	if composer.modify_tile(-1, 10, 1):
		_fail("brush wrote outside island")
		return
	if not composer.use_fixture(2) or composer.island.width != 8:
		_fail("layout switch failed")
		return
	if not composer.toggle_water(2, 2) or not composer.island.is_water(2, 2):
		_fail("water brush did not mark a wet tile")
		return
	if not composer.use_fixture(3) or composer.island.waterfall_edge_count() != 1:
		_fail("waterfall fixture did not load")
		return
	var filename: String = "user://test_sprint02_layout.json"
	if not composer.save_layout(filename):
		_fail("layout save failed")
		return
	composer.use_fixture(1)
	if not composer.load_layout(filename) or composer.island.width != 14 or composer.island.waterfall_edge_count() != 1:
		_fail("layout reload failed")
		return
	print("PASS — editor paints terrain and water, switches layouts, saves/loads river topology")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
