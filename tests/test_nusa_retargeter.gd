extends SceneTree
## Two compatible skeletons with a different shoulder rest orientation.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := _make_rig(0.0, 1.0)
	var target := _make_rig(0.65, 1.4)
	root.add_child(source)
	root.add_child(target)
	var profile: Dictionary = NusaRigProfile.load_profile()
	if not NusaRigProfile.inspect(source, profile)["valid"] or not NusaRigProfile.inspect(target, profile)["valid"]:
		_fail("synthetic rigs must satisfy canonical humanoid hierarchy")
		return
	var arm_id: int = source.find_bone("LeftUpperArm")
	var src_rest: Quaternion = source.get_bone_rest(arm_id).basis.get_rotation_quaternion()
	var swing := Quaternion(Vector3.RIGHT, 0.53)
	source.set_bone_pose_rotation(arm_id, swing)
	var src_root: int = source.find_bone("Hips")
	source.set_bone_pose_position(src_root, Vector3(0.0, 0.17, 0.0))
	var result: Dictionary = NusaAnimationRetargeter.retarget_pose(source, target, profile, profile)
	if not result["valid"] or not result["copied"].has("Arm_L"):
		_fail("retarget did not map left shoulder")
		return
	var target_id: int = target.find_bone("LeftUpperArm")
	var target_rest: Quaternion = target.get_bone_rest(target_id).basis.get_rotation_quaternion()
	var pose: Quaternion = target.get_bone_pose_rotation(target_id)
	var expected: Quaternion = NusaAnimationRetargeter.retarget_rotation(src_rest, swing, target_rest)
	if pose.angle_to(expected) > 0.002:
		_fail("target did not preserve source world-axis pose delta")
		return
	source.set_bone_pose_rotation(arm_id, Quaternion.IDENTITY)
	var neutral: Dictionary = NusaAnimationRetargeter.retarget_pose(source, target, profile, profile)
	if not neutral["valid"] or target.get_bone_pose_rotation(target_id).angle_to(Quaternion.IDENTITY) > 0.002:
		_fail("rest pose must stay neutral, never rotate twice by the rest basis")
		return
	source.set_bone_pose_rotation(arm_id, swing)
	NusaAnimationRetargeter.retarget_pose(source, target, profile, profile)
	pose = target.get_bone_pose_rotation(target_id)
	if absf(target.get_bone_pose_position(target.find_bone("Hips")).y - 0.17) > 0.002:
		_fail("root pose translation should not include rest position a second time")
		return
	var only: Array[String] = ["Arm_R"]
	var before: Quaternion = pose
	var partial: Dictionary = NusaAnimationRetargeter.retarget_pose(source, target, profile, profile, only)
	if partial["copied"].size() != 1 or target.get_bone_pose_rotation(target_id).angle_to(before) > 0.002:
		_fail("role filters must not modify unrelated bones")
		return
	print("PASS — canonical retarget preserves rest-axis rotations and filtered role transfer")
	quit(0)


func _make_rig(shoulder_angle: float, leg_size: float) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var definitions := [
		["Hips", -1, Vector3.ZERO], ["Spine", 0, Vector3(0, 0.20, 0)],
		["Head", 1, Vector3(0, 0.30, 0)],
		["LeftUpperArm", 1, Vector3(0.19, 0.1, 0)],
		["RightUpperArm", 1, Vector3(-0.19, 0.1, 0)],
		["LeftUpperLeg", 0, Vector3(0.12, -0.19 * leg_size, 0)],
		["RightUpperLeg", 0, Vector3(-0.12, -0.19 * leg_size, 0)]
	]
	for entry in definitions:
		var idx: int = skeleton.add_bone(entry[0])
		if int(entry[1]) >= 0:
			skeleton.set_bone_parent(idx, int(entry[1]))
		var rotation: Basis = Basis(Quaternion(Vector3.UP, shoulder_angle)) if idx == 3 else Basis.IDENTITY
		skeleton.set_bone_rest(idx, Transform3D(rotation, entry[2]))
	return skeleton


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
