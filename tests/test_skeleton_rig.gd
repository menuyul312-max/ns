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
	var rig: CharacterRigVisual = actor.rig_visual
	var animator: SkeletonAnimationBridge = actor.skeleton_bridge
	if rig == null or rig.skeleton == null or animator == null or not animator.initialized:
		_fail("Skeleton3D/AnimationTree pipeline did not initialize")
		return
	if not rig.imported_glb or rig.skeleton.get_bone_count() < 20:
		_fail("user GLB was not imported and mapped onto its actual skeleton")
		return
	if rig.skeleton.get_bone_count() < 7 or rig.bones.size() < 7:
		_fail("skeleton has missing roles")
		return
	if not rig.visible or actor.arm_joints[0].visible:
		_fail("skeleton view not default")
		return
	for state in SkeletonAnimationBridge.CLIPS:
		if not animator.animation_player.has_animation(state):
			_fail("missing rig clip " + state)
			return
	actor.set_start(5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(14):
		await physics_frame
	actor.set_input_direction(Vector2.RIGHT)
	for _i in range(18):
		await physics_frame
	if animator.current_clip != "walk" or str(animator.playback.get_current_node()) != "walk":
		_fail("rig did not enter walk")
		return
	var index: int = rig.skeleton.find_bone(str(rig.bones["Arm_L"]))
	var before: Quaternion = rig.skeleton.get_bone_pose_rotation(index)
	for _i in range(10):
		await physics_frame
	var after: Quaternion = rig.skeleton.get_bone_pose_rotation(index)
	if before.angle_to(after) < 0.07:
		_fail("skeleton bone rotation is not being animated: " + str(before) + " " + str(after))
		return
	actor.set_input_direction(Vector2.ZERO)
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	actor.mode = WaterRules.Mode.SWIM
	for _i in range(36):
		await physics_frame
	if animator.current_clip != "swim" or str(animator.playback.get_current_node()) != "swim":
		_fail("rig did not transition to swim")
		return
	if rig.depth_offset >= -0.05:
		_fail("visual waterline did not lower rig in deep water: " + str(rig.depth_offset))
		return
	actor.use_skeleton_rig = false
	actor.update_rig_visibility()
	if rig.visible or not actor.arm_joints[0].visible:
		_fail("A/B toggle to lab mannequin failed")
		return
	actor.use_skeleton_rig = true
	actor.update_rig_visibility()
	if not rig.visible:
		_fail("A/B toggle back to rig failed")
		return
	print("PASS — imported 23-bone GLB, AnimationTree keyframes, waterline offset, visual A/B")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
