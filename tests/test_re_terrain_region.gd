extends SceneTree
## Godot executable regression for RE terrain region mutations/checks.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var grid := NativeTerrainRegionReference.new(4, 3)
	for z in range(3):
		for x in range(4):
			grid.set_sample(x, z, 0x1f03, 10.0)
	if not grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 0):
		_fail("flat mode-0 region")
		return
	if not grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 1):
		_fail("flat mode-1 region")
		return
	grid.set_sample(2, 1, 0x1f03, 10.0, 10.5, 0)
	if grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 0):
		_fail("mode 0 ignores active overlay")
		return
	if not grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 1):
		_fail("mode 1 incorrectly used overlay")
		return
	grid.set_sample(2, 1, 0x1f03, 10.11)
	if not grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 1):
		_fail("inclusive float32 height threshold")
		return
	grid.set_sample(2, 1, 0x1f03, 10.111)
	if grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 1):
		_fail("out-of-threshold spread")
		return
	grid.set_sample(2, 1, 0x1f03, 10.0, 100.0, 7)
	if not grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 0):
		_fail("sentinel 7 inheritance")
		return
	if grid.mutate_region(Vector2i(2, 1), Vector2i(9, 9), NativeTerrainRegionReference.BIT_REGION_6, 1) != 4:
		_fail("inclusive clipped mutation count")
		return
	if grid.words[1] != 0x1f03 or grid.words[1 * 4 + 2] != 0x1f43:
		_fail("regional bit isolation")
		return
	if NativeTerrainRegionReference.decode_navigation_byte(0x1f00) != 31:
		_fail("bit 12 -> navigation bit 4 when bit 6 clear")
		return
	if NativeTerrainRegionReference.decode_navigation_byte(0x1f40) != 15:
		_fail("bit 6 inhibits navigation bit 4")
		return
	grid.mutate_region(Vector2i(2, 1), Vector2i(2, 1), NativeTerrainRegionReference.BIT_REGION_6, 2)
	if grid.words[1 * 4 + 2] != 0x1f03:
		_fail("mode low-bit clear")
		return
	grid.mutate_region(Vector2i(0, 0), Vector2i(0, 0), NativeTerrainRegionReference.BIT_REGION_2, 3)
	if grid.words[0] != 0x1f07:
		_fail("bit-2 mutation or mode 3")
		return
	grid.set_sample(0, 0, 0x1f02, 10.0)
	if grid.check_height_region(Vector2i.ZERO, Vector2i(3, 2), 0):
		_fail("missing mode-0 bit")
		return
	if not grid.check_height_region(Vector2i(40, 40), Vector2i(50, 50), 0):
		_fail("completely outside rectangle must pass")
		return
	print("PASS — RE region flag mutations, overlay inheritance, height checks and nav decoder")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
