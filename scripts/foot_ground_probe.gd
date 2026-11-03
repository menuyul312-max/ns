class_name FootGroundProbe
extends Node3D
## Per-foot terrain-contact targets for a future IK solver. Query-only:
## does not rotate any bone or change the CharacterBody3D capsule.

const TARGET_RAY_UP: float = 0.56
const TARGET_RAY_DOWN: float = 0.94
const FOOT_SURFACE_MASK: int = 41  # 1: terrain, 8: fine contact, 32: ramps/bridges; exclude props

var skeleton: Skeleton3D
var actor: RiverCharacter
var bone_indices: Dictionary = {}
var bone_anchors: Dictionary = {}
var foot_hits: Dictionary = {}
var sampled_count: int = 0
var show_debug: bool = false
var markers: Dictionary = {}


func setup(parent_actor: RiverCharacter, visual: CharacterRigVisual) -> void:
	actor = parent_actor
	skeleton = visual.skeleton
	name = "FootGroundTargets"
	for side in ["left", "right"]:
		var aliases: Array[String] = []
		if side == "left":
			aliases.assign(["LeftFoot", "Foot_L", "LeftAnkle", "Leg_L"])
		else:
			aliases.assign(["RightFoot", "Foot_R", "RightAnkle", "Leg_R"])
		for candidate in aliases:
			var index: int = skeleton.find_bone(candidate)
			if index >= 0:
				bone_indices[side] = index
				var anchor := BoneAttachment3D.new()
				anchor.name = "FootIKSource" + side.capitalize()
				anchor.bone_name = StringName(candidate)
				skeleton.add_child(anchor)
				bone_anchors[side] = anchor
				break
		foot_hits[side] = {"valid": false, "gap": INF, "world": Vector3.ZERO, "ground": Vector3.ZERO}
		var marker := MeshInstance3D.new()
		marker.name = "LeftGroundTarget" if side == "left" else "RightGroundTarget"
		marker.top_level = true
		marker.mesh = SphereMesh.new()
		(marker.mesh as SphereMesh).radius = 0.066
		(marker.mesh as SphereMesh).height = 0.132
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.42, 0.65) if side == "left" else Color(0.21, 0.98, 0.82)
		marker.material_override = material
		marker.visible = false
		add_child(marker)
		markers[side] = marker


func _physics_process(_delta: float) -> void:
	if skeleton == null or actor == null or actor.floating:
		for side in ["left", "right"]:
			if markers.has(side):
				(markers[side] as MeshInstance3D).visible = false
		return
	var state := get_world_3d().direct_space_state
	for side in ["left", "right"]:
		if not bone_indices.has(side):
			continue
		var anchor: BoneAttachment3D = bone_anchors[side]
		var foot_world: Vector3 = anchor.global_position
		var hit: Dictionary = state.intersect_ray(PhysicsRayQueryParameters3D.create(foot_world + Vector3.UP * TARGET_RAY_UP, foot_world - Vector3.UP * TARGET_RAY_DOWN, FOOT_SURFACE_MASK))
		var valid: bool = not hit.is_empty()
		var ground: Vector3 = hit["position"] if valid else Vector3.ZERO
		var gap: float = foot_world.y - ground.y if valid else INF
		foot_hits[side] = {"valid": valid, "gap": gap, "world": foot_world, "ground": ground}
		var marker: MeshInstance3D = markers[side]
		marker.visible = show_debug and valid
		if valid:
			marker.global_position = ground + Vector3.UP * 0.08
	sampled_count += 1
