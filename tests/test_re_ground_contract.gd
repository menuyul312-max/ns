extends SceneTree
## Reference contract tests, grounded in acnh-re-results at
## SHA 5309d6f2a7659c85a4bce1bee6561f0f136f46e0.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected: Dictionary = {
		-10.0: -3, -5.0: -2, -4.9: -1, -0.1: -1,
		0.0: 0, 4.9: 0, 5.0: 1, 10.0: 2
	}
	for value in expected:
		if NativeTerrainReference.native_index(float(value)) != int(expected[value]):
			_fail("negative-boundary coordinate conversion at %s" % value)
			return
	if NativeTerrainReference.cell_center(Vector2i.ZERO) != Vector2(2.5, 2.5):
		_fail("native index center displacement")
		return
	if NativeTerrainReference.sector(3.5, 0.5) != 0 or NativeTerrainReference.sector(0.5, 0.5) != 1 or NativeTerrainReference.sector(2.5, 2.5) != 2 or NativeTerrainReference.sector(4.5, 0.5) != 3:
		_fail("diagonal-sector geometry or equal-boundary branch")
		return
	var samples: Array[Vector2] = NativeTerrainReference.four_points(Vector2i.ZERO)
	var wanted: Array[Vector2] = [Vector2(2.5, 1.25), Vector2(1.25, 2.5), Vector2(2.5, 3.75), Vector2(3.75, 2.5)]
	if samples != wanted:
		_fail("native four-direction sample order")
		return
	var base := PackedByteArray([10, 20, 30, 40])
	var overlay := PackedByteArray([7, 9, 7, 4])
	var found: PackedByteArray = NativeTerrainReference.sample_four(Vector2i.ZERO, Vector2i.ZERO, 1, 1, base, overlay)
	if found != PackedByteArray([10, 9, 30, 4]):
		_fail("four-sector overlay inheritance or sample indexing: %s" % str(found))
		return
	if NativeTerrainReference.attribute_at(Vector2(20, 20), Vector2i.ZERO, 1, 1, base, overlay) != 7:
		_fail("out-of-map sentinel differs from source")
		return
	if not NativeTerrainReference.all_four_match(PackedByteArray([1, 1, 1, 1])):
		_fail("four-point all matcher")
		return
	if not NativeTerrainReference.any_four_match(PackedByteArray([0, 0, 1, 0])) or not NativeTerrainReference.exactly_two_match(PackedByteArray([1, 0, 1, 0])):
		_fail("native four-point boolean aggregators")
		return
	if NativeTerrainReference.exactly_two_match(PackedByteArray([2, 2, 0, 0])):
		_fail("unknown ground flags must not silently become true")
		return
	var nusantara := IslandDefinition.new(5, 5)
	var dry: Dictionary = NusantaraGroundQuery.sample_tile(nusantara, 2, 2)
	if dry["any_no_entry"] or dry["all_water"] or (dry["points"] as Array).size() != 4:
		_fail("original Godot terrain projection onto four directional probes")
		return
	nusantara.set_land(2, 2, false)
	var gap: Dictionary = NusantaraGroundQuery.sample_tile(nusantara, 2, 2)
	if not gap["any_no_entry"]:
		_fail("deleted land mask lost entry gate")
		return
	var policy: Dictionary = NativeCollisionPolicyReference.resolve(0, 2, 0, false, 0, 0x10)
	if policy["raw_mask"] != 0x80 or policy["collider_field_178"] != 0x11:
		_fail("native collision mode-0 branch")
		return
	policy = NativeCollisionPolicyReference.resolve(0, 2, 0, false, 1, 0x11)
	if policy["raw_mask"] != 0x201 or policy["collider_field_178"] != 0x11:
		_fail("native collision mode-0 predicate branch")
		return
	policy = NativeCollisionPolicyReference.resolve(2, 1, 0, true, 0, 0x11)
	if policy["raw_mask"] != 0x201 or policy["collider_field_178"] != 0x10:
		_fail("player selector override and collision flag clearance")
		return
	policy = NativeCollisionPolicyReference.resolve(0, 2, 0x40, false, 0, 0)
	if policy["effective_mode"] != 1 or policy["raw_mask"] != 0x201:
		_fail("flag bit 6 collision override")
		return
	policy = NativeCollisionPolicyReference.resolve(2, 2, 0x40, false, 0, 0x11)
	if policy["effective_mode"] != 2 or policy["raw_mask"] != 0 or policy["collider_field_178"] != 0x10:
		_fail("mode 2 immunity from bit-6 override")
		return
	print("PASS — RE coordinates, four diagonal sectors, overlay 7, ground predicates, bounded collision policy; Nusantara projection")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
