class_name DigImpactFX
extends Node3D
## Cosmetic soil indentation. It does not modify IslandDefinition or terrain.

const LIFETIME: float = 3.0
const MAX_MARKS: int = 8

var marks: Array[Dictionary] = []
var emitted_total: int = 0


func _ready() -> void:
	top_level = true


func stamp_at(position_world: Vector3) -> void:
	if marks.size() >= MAX_MARKS:
		_remove_oldest()
	var root_node := Node3D.new()
	root_node.name = "ShovelImpact"
	add_child(root_node)
	root_node.global_position = position_world + Vector3.UP * 0.037
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.39, 0.21, 0.12, 0.72)
	var disk := CylinderMesh.new()
	disk.top_radius = 0.20
	disk.bottom_radius = 0.20
	disk.height = 0.008
	var patch := MeshInstance3D.new()
	patch.name = "ExposedSoil"
	patch.mesh = disk
	patch.material_override = material
	root_node.add_child(patch)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.22, 0.13, 0.08, 0.84)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.20
	ring_mesh.outer_radius = 0.275
	var border := MeshInstance3D.new()
	border.name = "SoilRim"
	border.mesh = ring_mesh
	border.material_override = ring_mat
	border.position.y = 0.012
	root_node.add_child(border)
	marks.append({"node": root_node, "age": 0.0, "soil": material, "rim": ring_mat})
	emitted_total += 1


func _process(delta: float) -> void:
	for index in range(marks.size() - 1, -1, -1):
		var mark: Dictionary = marks[index]
		var age: float = float(mark["age"]) + delta
		if age >= LIFETIME:
			(mark["node"] as Node3D).queue_free()
			marks.remove_at(index)
			continue
		mark["age"] = age
		var opacity: float = 1.0 if age < 2.0 else (LIFETIME - age)
		var soil: StandardMaterial3D = mark["soil"]
		var soil_color: Color = soil.albedo_color
		soil_color.a = 0.72 * opacity
		soil.albedo_color = soil_color
		var rim: StandardMaterial3D = mark["rim"]
		var rim_color: Color = rim.albedo_color
		rim_color.a = 0.84 * opacity
		rim.albedo_color = rim_color
		marks[index] = mark


func _remove_oldest() -> void:
	var mark: Dictionary = marks.pop_front()
	(mark["node"] as Node3D).queue_free()
