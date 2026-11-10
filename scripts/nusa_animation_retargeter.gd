class_name NusaAnimationRetargeter
extends RefCounted
## Source/target Skeleton3D bone-role retargeting in Godot rest-pose space.
## This transfers a sampled pose; it does not solve different limb topologies.


static func retarget_rotation(source_rest: Quaternion, source_pose: Quaternion,
		target_rest: Quaternion) -> Quaternion:
	# Skeleton3D pose rotation is a DELTA relative to bone rest, with identity
	# representing the rest pose. Conjugate this delta into target rest axes:
	#   target_rest * target_delta * target_rest^-1
	#     = source_rest * source_delta * source_rest^-1.
	# Applying rest quaternion twice breaks neutral poses on nontrivial rigs.
	var orientation_change: Quaternion = target_rest.inverse() * source_rest
	return (orientation_change * source_pose * orientation_change.inverse()).normalized()


static func leg_scale(source: Skeleton3D, target: Skeleton3D,
		source_roles: Dictionary, target_roles: Dictionary) -> float:
	var source_length: float = _limb_length(source, source_roles)
	var target_length: float = _limb_length(target, target_roles)
	if source_length < 0.001 or target_length < 0.001:
		return 1.0
	return clampf(target_length / source_length, 0.2, 5.0)


static func _limb_length(skeleton: Skeleton3D, roles: Dictionary) -> float:
	var total: float = 0.0
	for role in ["Shin_L", "Foot_L"]:
		if roles.has(role):
			var bone_idx: int = skeleton.find_bone(str(roles[role]))
			if bone_idx >= 0:
				total += skeleton.get_bone_rest(bone_idx).origin.length()
	return total


static func retarget_pose(source: Skeleton3D, target: Skeleton3D,
		source_profile: Dictionary, target_profile: Dictionary,
		selected_roles: Array[String] = []) -> Dictionary:
	return apply_plan(source, target,
		make_plan(source, target, source_profile, target_profile, selected_roles))


static func make_plan(source: Skeleton3D, target: Skeleton3D,
		source_profile: Dictionary, target_profile: Dictionary,
		selected_roles: Array[String] = []) -> Dictionary:
	var source_report: Dictionary = NusaRigProfile.inspect(source, source_profile)
	var target_report: Dictionary = NusaRigProfile.inspect(target, target_profile)
	if not bool(source_report["valid"]) or not bool(target_report["valid"]):
		return {"valid": false, "channels": [], "reason": "incompatible skeleton/profile"}
	var source_roles: Dictionary = source_report["mapped"]
	var target_roles: Dictionary = target_report["mapped"]
	var scale: float = leg_scale(source, target, source_roles, target_roles)
	var channels: Array[Dictionary] = []
	for role in source_roles:
		if not target_roles.has(role) or not selected_roles.is_empty() and not selected_roles.has(role):
			continue
		var source_index: int = source.find_bone(str(source_roles[role]))
		var target_index: int = target.find_bone(str(target_roles[role]))
		channels.append({"role": str(role), "source_index": source_index,
			"target_index": target_index,
			"orientation_change": target.get_bone_rest(target_index).basis.get_rotation_quaternion().inverse()
				* source.get_bone_rest(source_index).basis.get_rotation_quaternion()})
	return {"valid": true, "channels": channels, "root_translation_scale": scale,
		"source_bones": source.get_bone_count(), "target_bones": target.get_bone_count()}


static func apply_plan(source: Skeleton3D, target: Skeleton3D, plan: Dictionary) -> Dictionary:
	if not bool(plan.get("valid", false)):
		return {"valid": false, "copied": [], "reason": str(plan.get("reason", "invalid plan"))}
	var copied: Array[String] = []
	for channel in plan["channels"]:
		var source_index: int = int(channel["source_index"])
		var target_index: int = int(channel["target_index"])
		var orientation: Quaternion = channel["orientation_change"]
		var source_pose: Quaternion = source.get_bone_pose_rotation(source_index)
		target.set_bone_pose_rotation(target_index,
			(orientation * source_pose * orientation.inverse()).normalized())
		if channel["role"] == "Root":
			# Pose position is also a rest-relative offset in Godot Skeleton3D.
			var delta: Vector3 = source.get_bone_pose_position(source_index)
			target.set_bone_pose_position(target_index,
				delta * float(plan["root_translation_scale"]))
		copied.append(str(channel["role"]))
	return {"valid": true, "copied": copied, "root_translation_scale": plan["root_translation_scale"],
		"source_bones": plan["source_bones"], "target_bones": plan["target_bones"]}
