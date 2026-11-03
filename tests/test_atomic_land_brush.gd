extends SceneTree
## RE table contains 1x1 and 3x3 action ranges; these atomic semantics are
## an original Nusantara safeguard, not a claim about ACNH transactions.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var composer := IslandComposer.new(IslandDefinition.new(8, 8))
	if not composer.set_land_area(4, 4, false, 1):
		_fail("valid 3x3 cove brush was rejected")
		return
	if composer.island.land_mask.count(0) != 9 or composer.island.is_land(3, 3) or composer.island.is_land(5, 5):
		_fail("3x3 deletion did not remove all nine cells")
		return
	if not composer.set_land_area(4, 4, true, 1) or composer.island.land_mask.count(0) != 0:
		_fail("3x3 beach fill did not restore all cells")
		return
	composer.island.set_occupant(5, 5, 1)
	if composer.set_land_area(4, 4, false, 1) or composer.last_edit_report["code"] != "MASK_OCCUPIED":
		_fail("3x3 brush ignored a protected tree")
		return
	if composer.island.land_mask.count(0) != 0:
		_fail("failed brush partially changed the terrain")
		return
	if composer.set_land_area(0, 0, false, 1) or composer.last_edit_report["code"] != "BRUSH_OUTSIDE":
		_fail("brush outside map was not rejected")
		return
	if not composer.set_land_area(2, 2, false, 0) or composer.island.is_land(2, 2):
		_fail("1x1 mode regressed")
		return
	var narrow := IslandComposer.new(IslandDefinition.new(3, 1))
	narrow.protect_connectivity = true
	if narrow.set_land_area(1, 0, false, 0) or narrow.last_edit_report["code"] != "MASK_ACCESS_SPLIT":
		_fail("atomic brush bypassed connectivity safeguards")
		return
	print("PASS — 1x1 and 3x3 atomic landmaking, rollback, safe bounds, access guard")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
