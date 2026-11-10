class_name NusaFaceController
extends Node
## Works with blend-shape names instead of hard-coded mesh indices. Any Nusa
## character can supply its own expressions.json without rebuilding the runtime.

const DEFAULT_EXPRESSIONS: String = "res://data/characters/expressions.json"

var shapes: Dictionary = {}
var presets: Dictionary = {}
var target_weights: Dictionary = {}
var current_expression: String = "neutral"
var transition_speed: float = 8.0
var suppress_mouth_morphs: bool = false


func setup(model_root: Node, expressions_path: String = DEFAULT_EXPRESSIONS) -> void:
	shapes.clear()
	_scan_meshes(model_root)
	presets.clear()
	if FileAccess.file_exists(expressions_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(expressions_path))
		if parsed is Dictionary:
			presets = parsed
	set_expression("neutral")


func _scan_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var part: MeshInstance3D = node as MeshInstance3D
		if part.mesh != null:
			for i in range(part.mesh.get_blend_shape_count()):
				var key: String = str(part.mesh.get_blend_shape_name(i))
				if not shapes.has(key):
					shapes[key] = []
				shapes[key].append({"mesh": part, "index": i})
	for child in node.get_children():
		_scan_meshes(child)


func set_expression(expression: String, seconds: float = 0.15) -> bool:
	if not presets.has(expression):
		return false
	current_expression = expression
	transition_speed = 1.0 / maxf(seconds, 0.001)
	target_weights.clear()
	var preset: Dictionary = presets[expression]
	for name in preset:
		if suppress_mouth_morphs and (str(name).begins_with("mouth") or str(name).begins_with("viseme") or str(name).begins_with("jaw")):
			continue
		if shapes.has(str(name)):
			target_weights[str(name)] = clampf(float(preset[name]), 0.0, 1.0)
	set_process(true)
	return true


func set_shape(name: String, value: float) -> bool:
	if not shapes.has(name):
		return false
	target_weights[name] = clampf(value, 0.0, 1.0)
	set_process(true)
	return true


func _process(delta: float) -> void:
	var settling: bool = false
	for key in shapes:
		var goal: float = float(target_weights.get(key, 0.0))
		for entry in shapes[key]:
			var mesh: MeshInstance3D = entry["mesh"]
			var idx: int = entry["index"]
			if not is_instance_valid(mesh):
				continue
			var previous: float = mesh.get_blend_shape_value(idx)
			var next_value: float = move_toward(previous, goal, transition_speed * delta)
			mesh.set_blend_shape_value(idx, next_value)
			if absf(goal - next_value) > 0.001:
				settling = true
	if not settling:
		set_process(false)


func available_shapes() -> Array[String]:
	var names: Array[String] = []
	for key in shapes:
		names.append(str(key))
	names.sort()
	return names
