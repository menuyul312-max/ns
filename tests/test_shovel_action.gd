extends SceneTree


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
	for _i in range(22):
		await physics_frame
	if not actor.is_on_floor():
		_fail("shovel test actor is not grounded")
		return
	var bridge: SkeletonAnimationBridge = actor.skeleton_bridge
	if bridge == null or not bridge.animation_player.has_animation("shovel"):
		_fail("shovel clip missing from skeletal AnimationPlayer")
		return
	if actor.shovel_prop == null or actor.shovel_prop.get_parent() != actor.rig_visual.skeleton:
		_fail("shovel tool not attached to imported skeleton")
		return
	if not actor.try_use_shovel() or not actor.shovel_prop.visible:
		_fail("on-land shovel action was rejected")
		return
	if actor.try_use_shovel():
		_fail("repeated input should not restart the OneShot action")
		return
	actor.set_input_direction(Vector2.RIGHT)
	for _i in range(8):
		await physics_frame
	for _i in range(2):
		await process_frame
	if not bool(bridge.animation_tree.get("parameters/action/active")):
		_fail("shovel OneShot did not become active")
		return
	if bridge.current_clip != "walk":
		_fail("shovel action replaced the locomotion state")
		return
	var tip: MeshInstance3D = actor.shovel_prop.get_node("WorldAlignedGrip/PointedTip")
	if tip.global_position.y > actor.shovel_prop.global_position.y - 0.15:
		_fail("shovel tip no longer points down from the imported right hand")
		return
	var thigh_index: int = actor.rig_visual.skeleton.find_bone(str(actor.rig_visual.bones["Leg_L"]))
	var initial: Quaternion = actor.rig_visual.skeleton.get_bone_pose_rotation(thigh_index)
	for _i in range(9):
		await physics_frame
	var updated: Quaternion = actor.rig_visual.skeleton.get_bone_pose_rotation(thigh_index)
	if initial.angle_to(updated) < 0.04:
		_fail("lower-body locomotion froze during upper-body shovel action")
		return
	for _i in range(24):
		await physics_frame
	if actor.impact_effects.emitted_total != 1:
		_fail("shovel impact should mark soil exactly once: " + str(actor.impact_effects.emitted_total))
		return
	actor.set_input_direction(Vector2.ZERO)
	for _i in range(55):
		await physics_frame
	if bridge.shovel_active() or actor.shovel_prop.visible:
		_fail("prop remained equipped after shovel recovery")
		return
	if not actor.try_use_shovel():
		_fail("shovel did not become available again after recovery")
		return
	actor.mode = WaterRules.Mode.SWIM
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	for _i in range(90):
		await physics_frame
	if actor.try_use_shovel():
		_fail("shovel should be blocked while swimming")
		return
	actor.impact_effects._process(DigImpactFX.LIFETIME + 0.05)
	if not actor.impact_effects.marks.is_empty():
		_fail("old impact marks were not disposed")
		return
	print("PASS — grounded shovel OneShot, locomotion legs, dig impact, cooldown, swim restriction")
	quit(0)


func _fail(reason: String) -> void:
	push_error("FAIL — " + reason)
	quit(1)
