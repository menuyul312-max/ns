class_name NusaRetargetPlayback
extends RefCounted
## Offline/runtime clip sampler for multiple compatible biped Skeleton3Ds.
## The source animation is used as a pose library; all target deforming skin
## and face art remain authored per character. Not a topology solver.

var source_animation: AnimationPlayer
var source_skeleton: Skeleton3D
var target_skeleton: Skeleton3D
var plan: Dictionary = {}
var clip_name: String = ""
var elapsed: float = 0.0
var source_baseline: Dictionary = {}
var target_baseline: Dictionary = {}
var source_position_baseline: Dictionary = {}
var target_position_baseline: Dictionary = {}


func setup(source_player: AnimationPlayer, source: Skeleton3D, target: Skeleton3D,
		source_profile: Dictionary, target_profile: Dictionary) -> bool:
	source_animation = source_player
	source_skeleton = source
	target_skeleton = target
	plan = NusaAnimationRetargeter.make_plan(source, target, source_profile, target_profile)
	if not bool(plan.get("valid", false)) or source_animation == null:
		return false
	# Legacy imported motion tracks use an authored relaxed-arm idle posture,
	# whereas the second GLB has a different neutral/A-pose. Record both actual
	# base poses once, then carry only the animation DIFFERENCE to the target.
	if source_animation.has_animation("idle"):
		source_animation.play("idle")
		source_animation.advance(0.0)
		source_animation.seek(0.0, true)
	for channel in plan["channels"]:
		var source_idx: int = int(channel["source_index"])
		var target_idx: int = int(channel["target_index"])
		source_baseline[source_idx] = source.get_bone_pose_rotation(source_idx)
		target_baseline[target_idx] = target.get_bone_pose_rotation(target_idx)
		source_position_baseline[source_idx] = source.get_bone_pose_position(source_idx)
		target_position_baseline[target_idx] = target.get_bone_pose_position(target_idx)
	return true


func play(name: String) -> bool:
	if not bool(plan.get("valid", false)) or source_animation == null or not source_animation.has_animation(name):
		return false
	clip_name = name
	elapsed = 0.0
	source_animation.play(name)
	source_animation.advance(0.0)
	return true


func sample(time: float) -> Dictionary:
	if clip_name.is_empty():
		return {"valid": false, "reason": "no active clip"}
	var clip: Animation = source_animation.get_animation(clip_name)
	if clip == null or clip.length <= 0.0:
		return {"valid": false, "reason": "missing/empty clip"}
	elapsed = fposmod(time, clip.length) if clip.loop_mode != Animation.LOOP_NONE else clampf(time, 0.0, clip.length - 0.00001)
	source_animation.seek(elapsed, true)
	var copied: Array[String] = []
	for channel in plan["channels"]:
		var source_idx: int = int(channel["source_index"])
		var target_idx: int = int(channel["target_index"])
		var source_neutral: Quaternion = source_baseline[source_idx]
		var target_neutral: Quaternion = target_baseline[target_idx]
		var correction: Quaternion = channel["orientation_change"]
		var difference: Quaternion = source_neutral.inverse() * source_skeleton.get_bone_pose_rotation(source_idx)
		target_skeleton.set_bone_pose_rotation(target_idx,
			(target_neutral * correction * difference * correction.inverse()).normalized())
		if channel["role"] == "Root":
			var delta: Vector3 = source_skeleton.get_bone_pose_position(source_idx) - source_position_baseline[source_idx]
			target_skeleton.set_bone_pose_position(target_idx,
				target_position_baseline[target_idx] + delta * float(plan["root_translation_scale"]))
		copied.append(str(channel["role"]))
	target_skeleton.force_update_all_bone_transforms()
	return {"valid": true, "copied": copied, "root_translation_scale": plan["root_translation_scale"]}


func advance(delta: float) -> Dictionary:
	return sample(elapsed + maxf(0.0, delta))
