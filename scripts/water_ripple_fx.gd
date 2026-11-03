class_name WaterRippleFX
extends Node3D
## Small original gameplay feedback: expanding flat rings above river surface.
## This is visual feedback, not a fluid solver or a particle simulation.

const MAX_RIPPLES: int = 12
const LIFETIME: float = 0.95

var active_ripples: Array[Dictionary] = []
var emitted_total: int = 0
var ring_mesh: ArrayMesh


func _ready() -> void:
	# Keep spawned rings in world coordinates when the character moves.
	top_level = true
	ring_mesh = _create_ring_mesh()


func emit_at(surface_position: Vector3, strength: float = 1.0) -> void:
	if ring_mesh == null:
		ring_mesh = _create_ring_mesh()
	if active_ripples.size() >= MAX_RIPPLES:
		_remove_oldest()
	var ring := MeshInstance3D.new()
	ring.name = "WaterRipple"
	ring.mesh = ring_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	material.albedo_color = Color(0.98, 1.0, 1.0, 0.94)
	ring.material_override = material
	add_child(ring)
	ring.global_position = surface_position + Vector3.UP * 0.065
	ring.scale = Vector3.ONE * 0.13
	active_ripples.append({"node": ring, "material": material, "age": 0.0, "strength": clampf(strength, 0.5, 1.8)})
	emitted_total += 1


func _process(delta: float) -> void:
	for i in range(active_ripples.size() - 1, -1, -1):
		var ripple: Dictionary = active_ripples[i]
		var age: float = float(ripple["age"]) + delta
		if age >= LIFETIME:
			var old: MeshInstance3D = ripple["node"]
			old.queue_free()
			active_ripples.remove_at(i)
			continue
		ripples_set_age(i, age)


func ripples_set_age(index: int, age: float) -> void:
	var ripple: Dictionary = active_ripples[index]
	ripple_update(index, ripple, age)


func ripple_update(index: int, ripple: Dictionary, age: float) -> void:
	var amount: float = age / LIFETIME
	var strength: float = float(ripple["strength"])
	var node: MeshInstance3D = ripple["node"]
	var radius: float = (0.13 + amount * 1.17) * strength
	node.scale = Vector3(radius, 1.0, radius)
	var material: StandardMaterial3D = ripple["material"]
	material.albedo_color = Color(0.98, 1.0, 1.0, 0.90 * pow(1.0 - amount, 1.10))
	ripple["age"] = age
	active_ripples[index] = ripple


func _remove_oldest() -> void:
	var ripple: Dictionary = active_ripples.pop_front()
	var node: MeshInstance3D = ripple["node"]
	node.queue_free()


func _create_ring_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	const SEGMENTS: int = 32
	for segment in range(SEGMENTS):
		var a: float = TAU * float(segment) / float(SEGMENTS)
		var b: float = TAU * float(segment + 1) / float(SEGMENTS)
		var inward_a := Vector3(cos(a) * 0.75, 0.0, sin(a) * 0.75)
		var outward_a := Vector3(cos(a), 0.0, sin(a))
		var inward_b := Vector3(cos(b) * 0.75, 0.0, sin(b) * 0.75)
		var outward_b := Vector3(cos(b), 0.0, sin(b))
		vertices.append_array(PackedVector3Array([inward_a, outward_a, outward_b, inward_a, outward_b, inward_b]))
		for _j in range(6):
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
