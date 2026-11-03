extends SceneTree
## Numerical A/B evidence: rest alignment, two-bone ankle motion,
## stepping, locomotion bypass, and swimming safety.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	root.add_child(TerrainBuilder.build_world(island))
	root.add_child(WaterBuilder.build_world(island))
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	actor.current_enabled = false
	root.add_child(actor)
	actor.set_start(5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(35):
		await physics_frame
	var ik: FootIKController = actor.foot_ik
	if ik.modifiers.size() != 2 or ik.reference_clearance.size() != 2:
		_fail("did not configure/calibrate both native leg IK chains: " + str(ik.reference_clearance))
		return
	if absf(float(actor.foot_probe.foot_hits["left"]["gap"])) > 0.2:
		_fail("imported rest rotations still put the ankles away from ground")
		return
	# Fine surface patch, sensed by ankle IK only; the larger character capsule
	# retains the stable base ground collision surface.
	var foot: Vector3 = actor.foot_probe.foot_hits["right"]["world"]
	var patch := StaticBody3D.new()
	patch.name = "SmallGroundBump"
	patch.collision_layer = 8
	patch.collision_mask = 0
	patch.position = Vector3(foot.x, 1.55 + 0.055, foot.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.10, 0.11, 0.10)
	shape.shape = box
	patch.add_child(shape)
	root.add_child(patch)
	# Compare uncorrected and IK-corrected poses at the same contact patch.
	ik.set_ik_enabled(false)
	for _i in range(12):
		await physics_frame
	var before: Vector3 = actor.foot_probe.foot_hits["right"]["world"]
	var target_y: float = patch.global_position.y + 0.055 + float(ik.reference_clearance["right"])
	var error_before: float = absf(before.y - target_y)
	ik.set_ik_enabled(true)
	for _i in range(15):
		await physics_frame
	var after: Vector3 = actor.foot_probe.foot_hits["right"]["world"]
	var error_after: float = absf(after.y - target_y)
	print("IK A/B: gap_before=", error_before, " gap_after=", error_after, " reference=", ik.reference_clearance, " active=", ik.active_sides, " foot_before=", before, " foot_after=", after)
	if not bool(ik.active_sides["right"]):
		_fail("right leg IK did not activate above the contact patch")
		return
	if not error_after + 0.015 < error_before:
		_fail("two-bone IK failed to improve ankle target: before=" + str(error_before) + ", after=" + str(error_after))
		return
	# An impossible vertical obstacle must be rejected, not make the leg snap.
	patch.position.y += 0.30
	for _i in range(8):
		await physics_frame
	if bool(ik.active_sides["right"]):
		_fail("ankle IK attempted to reach a foot-high vertical obstacle")
		return
	actor.set_input_direction(Vector2.RIGHT)
	for _i in range(8):
		await physics_frame
	if bool(ik.active_sides["left"]) or bool(ik.active_sides["right"]):
		_fail("idle IK should release during gait to avoid foot sliding")
		return
	actor.mode = WaterRules.Mode.SWIM
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	actor.set_input_direction(Vector2.ZERO)
	for _i in range(40):
		await physics_frame
	if not actor.floating or bool(ik.active_sides["left"]) or bool(ik.active_sides["right"]):
		_fail("IK did not deactivate while floating")
		return
	print("PASS — imported rest pose aligned, native ankle IK reduces bump error, gait/swim bypass")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
