class_name ShovelTool
extends BoneAttachment3D
## A small, original hand-trowel prop. The bone controls grip position; a
## child pivot keeps the shaft pointing toward soil despite imported hand axes.

var actor: RiverCharacter
var shaft_pivot: Node3D


func setup(skeleton: Skeleton3D, bone_roles: Dictionary, parent_actor: RiverCharacter = null) -> void:
	name = "EquippedShovel"
	actor = parent_actor
	var hand: String = str(bone_roles.get("Hand_R", bone_roles.get("Arm_R", "")))
	if skeleton.find_bone(hand) < 0:
		hand = str(bone_roles.get("Arm_R", ""))
	bone_name = StringName(hand)
	skeleton.add_child(self)
	visible = false
	shaft_pivot = Node3D.new()
	shaft_pivot.name = "WorldAlignedGrip"
	add_child(shaft_pivot)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.40, 0.24, 0.12)
	wood.roughness = 0.72
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.53, 0.69, 0.72)
	metal.metallic = 0.45
	metal.roughness = 0.35
	var grip := CylinderMesh.new()
	grip.top_radius = 0.019
	grip.bottom_radius = 0.021
	grip.height = 0.19
	_add_part("WoodenShaft", grip, Vector3(0.0, -0.025, 0.0), wood)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.035
	collar.bottom_radius = 0.035
	collar.height = 0.055
	_add_part("MetalCollar", collar, Vector3(0.0, -0.14, 0.0), metal)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.14, 0.10, 0.034)
	_add_part("SpadeBlade", blade, Vector3(0.0, -0.20, 0.0), metal)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.135, 0.05, 0.03)
	_add_part("PointedTip", tip, Vector3(0.0, -0.27, 0.0), metal)


func _process(_delta: float) -> void:
	if not visible or actor == null or shaft_pivot == null or actor.skeleton_bridge == null:
		return
	var elapsed: float = actor.skeleton_bridge.shovel_elapsed
	var forward: Vector3 = actor.mesh_root.global_transform.basis * Vector3.FORWARD
	# At contact the blade leans forward, but its Y-axis never inherits the
	# upside-down local axis of RightHand from the GLB.
	var lean: float = 0.12 if elapsed < 0.26 else (0.55 if elapsed < 0.75 else 0.25)
	var desired_down: Vector3 = (Vector3.DOWN + forward.normalized() * lean).normalized()
	var world_grip_rotation := Quaternion(Vector3.DOWN, desired_down)
	shaft_pivot.quaternion = global_transform.basis.orthonormalized().get_rotation_quaternion().inverse() * world_grip_rotation


func _add_part(part_name: String, mesh: Mesh, offset: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	shaft_pivot.add_child(part)
