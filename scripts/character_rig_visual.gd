class_name CharacterRigVisual
extends Node3D
## Experimental Skeleton3D-driven visual adapter. Accepts a GLB when present;
## otherwise builds an original debug rig with BoneAttachment3D mesh stand-ins.
## Neither the fallback meshes nor this basic bone mapping are finished art.

const OPTIONAL_GLB_PATH: String = "res://assets/character_nusantara.glb"
const DEFAULT_PROFILE_PATH: String = NusaRigProfile.HUMANOID
const ALIASES := {
	"Root": ["Root", "root", "Hips", "hips", "mixamorig:Hips"],
	"Spine": ["Spine", "spine", "Spine1", "mixamorig:Spine"],
	"Head": ["Head", "head", "mixamorig:Head"],
	"Arm_L": ["Arm_L", "LeftArm", "LeftUpperArm", "upper_arm.L", "mixamorig:LeftArm"],
	"Arm_R": ["Arm_R", "RightArm", "RightUpperArm", "upper_arm.R", "mixamorig:RightArm"],
	"Leg_L": ["Leg_L", "LeftUpLeg", "LeftUpperLeg", "thigh.L", "mixamorig:LeftUpLeg"],
	"Leg_R": ["Leg_R", "RightUpLeg", "RightUpperLeg", "thigh.R", "mixamorig:RightUpLeg"]
}

var skeleton: Skeleton3D
var bones: Dictionary = {}
var source_label: String = "DEBUG SKELETON"
var imported_glb: bool = false
var depth_offset: float = 0.0
var glb_path: String = OPTIONAL_GLB_PATH
var profile_path: String = DEFAULT_PROFILE_PATH
var rig_profile: Dictionary = {}
var rig_report: Dictionary = {}
var face_controller: NusaFaceController
var attachment_nodes: Dictionary = {}
var visual_scale: float = 1.20
var visual_offset: Vector3 = Vector3(0.0, -0.61, 0.0)


func configure_asset(model_path: String, rig_profile_path: String = DEFAULT_PROFILE_PATH,
		scale_factor: float = 1.20, offset: Vector3 = Vector3(0.0, -0.61, 0.0)) -> void:
	glb_path = model_path
	profile_path = rig_profile_path
	visual_scale = scale_factor
	visual_offset = offset


func setup() -> void:
	rig_profile = NusaRigProfile.load_profile(profile_path)
	if not _try_import_glb():
		_build_proxy()


func set_waterline(depth: float, wet: bool, delta: float) -> void:
	# Cosmetics only; the CharacterBody3D collision capsule never shrinks.
	var target: float = -minf(depth * 0.18, 0.14) if wet else 0.0
	depth_offset = move_toward(depth_offset, target, delta * 0.45)
	position.y = depth_offset


func _try_import_glb() -> bool:
	if not ResourceLoader.exists(glb_path):
		return false
	var resource: Resource = load(glb_path)
	if not resource is PackedScene:
		push_warning("Character GLB was not imported as PackedScene; using test rig")
		return false
	var scene: Node = (resource as PackedScene).instantiate()
	var found: Skeleton3D = _find_skeleton(scene)
	if found == null:
		scene.free()
		push_warning("GLB has no Skeleton3D; using test rig")
		return false
	var report: Dictionary = NusaRigProfile.inspect(found, rig_profile)
	if not bool(report["valid"]):
		scene.free()
		push_warning("GLB rig incompatible with %s: %s %s" % [profile_path,
			str(report["missing_required"]), str(report["hierarchy_errors"])])
		return false
	add_child(scene)
	scene.name = "ImportedNusantaraGLB"
	if scene is Node3D:
		# Kept configurable: a new character must not inherit an unrelated
		# chibi's scale or capsule/feet calibration by accident.
		(scene as Node3D).scale = Vector3.ONE * visual_scale
		(scene as Node3D).position = visual_offset
	skeleton = found
	bones = report["mapped"]
	rig_report = report
	imported_glb = true
	source_label = "IMPORTED GLB"
	face_controller = NusaFaceController.new()
	face_controller.name = "NusaFaceController"
	add_child(face_controller)
	face_controller.setup(scene)
	return true


static func map_bones(rig: Skeleton3D) -> Dictionary:
	var profile: Dictionary = NusaRigProfile.load_profile()
	if not profile.is_empty():
		return NusaRigProfile.inspect(rig, profile)["mapped"]
	var mapping: Dictionary = {}
	for role in ALIASES.keys():
		for alias in ALIASES[role]:
			var bone_index: int = rig.find_bone(alias)
			if bone_index >= 0:
				mapping[role] = rig.get_bone_name(bone_index)
				break
	return mapping


func attach_module(socket_name: String, module_scene: PackedScene,
		local_pose: Transform3D = Transform3D.IDENTITY) -> bool:
	if skeleton == null or module_scene == null:
		return false
	var bone: String = NusaRigProfile.bone_for_socket(bones, rig_profile, socket_name)
	if bone.is_empty():
		return false
	if attachment_nodes.has(socket_name):
		(attachment_nodes[socket_name] as Node).queue_free()
	var attachment := BoneAttachment3D.new()
	attachment.name = "Module_" + socket_name
	attachment.bone_name = StringName(bone)
	skeleton.add_child(attachment)
	var module: Node = module_scene.instantiate()
	if not module is Node3D:
		attachment.queue_free()
		module.free()
		return false
	attachment.add_child(module)
	(module as Node3D).transform = local_pose
	attachment_nodes[socket_name] = attachment
	return true


func set_expression(name: String, duration: float = 0.15) -> bool:
	return face_controller != null and face_controller.set_expression(name, duration)


func _find_skeleton(candidate: Node) -> Skeleton3D:
	if candidate is Skeleton3D:
		return candidate as Skeleton3D
	for node in candidate.get_children():
		var result: Skeleton3D = _find_skeleton(node)
		if result != null:
			return result
	return null


func _build_proxy() -> void:
	rig_report = {"valid": false, "source": "debug_proxy", "reason": "GLB missing or incompatible"}
	skeleton = Skeleton3D.new()
	skeleton.name = "NusantaraSkeleton"
	add_child(skeleton)
	var hierarchy := [
		["Root", -1, Vector3.ZERO],
		["Spine", 0, Vector3(0.0, -0.16, 0.0)],
		["Head", 1, Vector3(0.0, 0.49, -0.01)],
		["Arm_L", 1, Vector3(-0.245, 0.16, 0.0)],
		["Arm_R", 1, Vector3(0.245, 0.16, 0.0)],
		["Leg_L", 0, Vector3(-0.12, -0.31, 0.02)],
		["Leg_R", 0, Vector3(0.12, -0.31, 0.02)]
	]
	for entry in hierarchy:
		var index: int = skeleton.add_bone(entry[0])
		if int(entry[1]) >= 0:
			skeleton.set_bone_parent(index, int(entry[1]))
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, entry[2]))
	bones = map_bones(skeleton)
	_add_body_parts()


func _add_body_parts() -> void:
	var face := Color(0.88, 0.63, 0.43)
	var shirt := Color(0.17, 0.41, 0.37)
	var batik := Color(0.35, 0.25, 0.41)
	var torso := CapsuleMesh.new()
	torso.radius = 0.20
	torso.height = 0.59
	_add_bone_mesh("Spine", "Torso", torso, Vector3(0.0, -0.055, 0.0), shirt)
	var head := SphereMesh.new()
	head.radius = 0.245
	head.height = 0.47
	_add_bone_mesh("Head", "Head", head, Vector3(0.0, 0.045, -0.006), face)
	var hair := SphereMesh.new()
	hair.radius = 0.243
	hair.height = 0.14
	_add_bone_mesh("Head", "HairCap", hair, Vector3(0.0, 0.246, -0.006), Color(0.12, 0.09, 0.09))
	var cloth := TorusMesh.new()
	cloth.inner_radius = 0.206
	cloth.outer_radius = 0.252
	_add_bone_mesh("Head", "IkatHeadband", cloth, Vector3(0.0, 0.18, 0.0), Color(0.77, 0.30, 0.22))
	for side in [-1.0, 1.0]:
		var side_name: String = "L" if side < 0.0 else "R"
		var eye := SphereMesh.new()
		eye.radius = 0.024
		eye.height = 0.048
		_add_bone_mesh("Head", "Eye" + side_name, eye, Vector3(side * 0.078, 0.067, -0.228), Color(0.08, 0.13, 0.16))
		var sleeve := CapsuleMesh.new()
		sleeve.radius = 0.073
		sleeve.height = 0.39
		_add_bone_mesh("Arm_" + side_name, "Sleeve" + side_name, sleeve, Vector3(0.0, -0.18, 0.0), shirt)
		var hand := SphereMesh.new()
		hand.radius = 0.075
		hand.height = 0.14
		_add_bone_mesh("Arm_" + side_name, "Hand" + side_name, hand, Vector3(0.0, -0.35, 0.0), face)
		var pants := CapsuleMesh.new()
		pants.radius = 0.09
		pants.height = 0.34
		_add_bone_mesh("Leg_" + side_name, "Trousers" + side_name, pants, Vector3(0.0, -0.15, 0.02), batik)
		var foot := CapsuleMesh.new()
		foot.radius = 0.097
		foot.height = 0.18
		_add_bone_mesh("Leg_" + side_name, "Foot" + side_name, foot, Vector3(0.0, -0.31, -0.065), Color(0.29, 0.19, 0.16))


func _add_bone_mesh(role: String, part_name: String, mesh: Mesh, offset: Vector3, tint: Color) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.name = part_name + "Anchor"
	attachment.bone_name = StringName(bones[role])
	skeleton.add_child(attachment)
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.79
	part.material_override = mat
	attachment.add_child(part)
