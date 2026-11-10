class_name FootIKController
extends Node3D
## Terrain-aware idle-stance correction using Godot's native TwoBoneIK3D.
## Visual skeleton only; never moves the collision capsule or edits terrain.

const SIDES: Array[String] = ["left", "right"]
const MAX_STEP_DELTA: float = 0.15
const MAX_REFERENCE_GAP: float = 0.20

var actor: RiverCharacter
var rig: CharacterRigVisual
var probe: FootGroundProbe
var modifiers: Dictionary = {}
var targets: Dictionary = {}
var poles: Dictionary = {}
var reference_clearance: Dictionary = {}
var enabled_by_player: bool = true
var active_sides: Dictionary = {"left": false, "right": false}
var corrected_frames: int = 0


func setup(parent_actor: RiverCharacter, visual: CharacterRigVisual, source: FootGroundProbe) -> void:
	name = "TerrainFootIK"
	actor = parent_actor
	rig = visual
	probe = source
	if not visual.imported_glb:
		return
	for side in SIDES:
		var prefix: String = "Left" if side == "left" else "Right"
		var suffix: String = "L" if side == "left" else "R"
		var bone_names: Array[String] = [str(rig.bones.get("Leg_" + suffix, "")),
			str(rig.bones.get("Shin_" + suffix, "")), str(rig.bones.get("Foot_" + suffix, ""))]
		var has_bones: bool = true
		for bone_name in bone_names:
			if rig.skeleton.find_bone(bone_name) < 0:
				has_bones = false
		if not has_bones:
			continue
		var target := Node3D.new()
		target.name = prefix + "AnkleIKTarget"
		target.top_level = true
		add_child(target)
		target.global_position = (probe.bone_anchors[side] as BoneAttachment3D).global_position
		targets[side] = target
		var pole := Node3D.new()
		pole.name = prefix + "KneePole"
		pole.top_level = true
		add_child(pole)
		poles[side] = pole
		var ik := TwoBoneIK3D.new()
		ik.name = prefix + "LegTwoBoneIK"
		rig.skeleton.add_child(ik)
		ik.set_setting_count(1)
		ik.set_root_bone_name(0, bone_names[0])
		ik.set_middle_bone_name(0, bone_names[1])
		ik.set_end_bone_name(0, bone_names[2])
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(pole))
		ik.set_active(false)
		modifiers[side] = ik


func _physics_process(_delta: float) -> void:
	if actor == null or probe == null:
		return
	var idle_grounded: bool = enabled_by_player and actor.is_on_floor() and not actor.floating and actor.motion_state == RiverCharacter.MotionState.IDLE and actor.use_skeleton_rig
	for side in SIDES:
		if not modifiers.has(side):
			continue
		var modifier: TwoBoneIK3D = modifiers[side]
		var valid: bool = idle_grounded and bool(probe.foot_hits[side]["valid"])
		var sample: Dictionary = probe.foot_hits[side]
		var gap: float = float(sample["gap"])
		if valid and not reference_clearance.has(side):
			# Measure once, after grounded settling. The GLB foot bone is
			# an ankle joint, NOT a sole contact point.
			if gap >= 0.0 and gap <= MAX_REFERENCE_GAP:
				reference_clearance[side] = gap
			else:
				valid = false
		if valid and reference_clearance.has(side):
			var foot_world: Vector3 = sample["world"]
			var ground: Vector3 = sample["ground"]
			var desired: Vector3 = Vector3(foot_world.x, ground.y + float(reference_clearance[side]), foot_world.z)
			# The island's tall (1.55 m) cliffs cannot be reached by a
			# 0.3 m leg: avoid IK stretching/snap across cliff edges.
			if absf(desired.y - foot_world.y) <= MAX_STEP_DELTA:
				(targets[side] as Node3D).global_position = desired
				var knee_index: int = rig.skeleton.find_bone(str(rig.bones.get("Shin_L" if side == "left" else "Shin_R", "")))
				var knee_world: Vector3 = rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(knee_index).origin)
				# Pole follows the actor's facing direction to keep knee bend stable.
				var pole_forward: Vector3 = actor.mesh_root.global_transform.basis * Vector3(0.0, 0.0, 1.0)
				(poles[side] as Node3D).global_position = knee_world + pole_forward.normalized() * 0.4
				modifier.set_active(true)
				active_sides[side] = true
				corrected_frames += 1
				continue
		modifier.set_active(false)
		active_sides[side] = false


func set_ik_enabled(next_enabled: bool) -> void:
	enabled_by_player = next_enabled
	if not next_enabled:
		for side in SIDES:
			if modifiers.has(side):
				(modifiers[side] as TwoBoneIK3D).set_active(false)
			active_sides[side] = false
