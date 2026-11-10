class_name NusaCollisionProfile
extends RefCounted
## Physical gameplay collision, not a mesh-based hitbox approximation.

const HUMANOID: String = "res://data/characters/collisions/humanoid.json"


static func load_profile(path: String = HUMANOID, depth: int = 0) -> Dictionary:
	if depth > 4 or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var result: Dictionary = parsed.duplicate(true)
	if result.has("extends"):
		var parent: String = str(result["extends"])
		if parent.is_empty() or parent.contains("/") or parent.contains("."):
			return {}
		var inherited: Dictionary = load_profile(path.get_base_dir().path_join(parent + ".json"), depth + 1)
		if inherited.is_empty():
			return {}
		inherited.merge(result, true)
		result = inherited
	return result if validate(result).is_empty() else {}


static func validate(profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["radius", "height", "foot_offset", "interaction_radius", "interaction_forward", "interaction_height"]:
		if not profile.has(field) or not profile[field] is float and not profile[field] is int:
			errors.append("missing numeric " + field)
	var radius: float = float(profile.get("radius", 0.0))
	var height: float = float(profile.get("height", 0.0))
	var foot: float = float(profile.get("foot_offset", 0.0))
	if radius <= 0.0 or height < radius * 2.0 or height > 3.0:
		errors.append("invalid capsule dimensions")
	if absf(foot - height * 0.5) > 0.001:
		errors.append("foot_offset must match half of capsule height")
	if float(profile.get("interaction_radius", 0.0)) <= 0.0:
		errors.append("invalid interaction sensor radius")
	if float(profile.get("interaction_forward", -1.0)) < 0.0:
		errors.append("interaction_forward must be nonnegative")
	for field in ["body_layer", "world_mask", "interaction_mask"]:
		if not profile.has(field) or int(profile[field]) < 0:
			errors.append("invalid collision mask " + field)
	return errors
