class_name NusaRigProfile
extends RefCounted
## Original Nusa bone-role contract. ACNH is a reference for data organisation,
## not a source of game-ready rigs or Nintendo animation assets.

const HUMANOID: String = "res://data/characters/profiles/humanoid.json"


static func load_profile(path: String = HUMANOID, depth: int = 0) -> Dictionary:
	if depth > 4:
		return {}
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var current: Dictionary = parsed
	if not current.has("extends"):
		return current
	var parent_name: String = str(current["extends"])
	if parent_name.is_empty() or parent_name.contains("/") or parent_name.contains("."):
		return {}
	var base: Dictionary = load_profile(path.get_base_dir().path_join(parent_name + ".json"), depth + 1)
	if base.is_empty():
		return {}
	for field in ["aliases", "sockets"]:
		var merged: Dictionary = base.get(field, {}).duplicate(true)
		merged.merge(current.get(field, {}), true)
		base[field] = merged
	for field in ["required_roles", "optional_roles", "ancestor_rules"]:
		var entries: Array = base.get(field, []).duplicate(true)
		for entry in current.get(field, []):
			if not entries.has(entry):
				entries.append(entry)
		base[field] = entries
	base["id"] = current.get("id", base.get("id"))
	base["description"] = current.get("description", base.get("description"))
	return base


static func inspect(skeleton: Skeleton3D, profile: Dictionary) -> Dictionary:
	var mapped: Dictionary = {}
	var missing_required: Array[String] = []
	var missing_optional: Array[String] = []
	var hierarchy_errors: Array[String] = []
	if skeleton == null or not profile.has("aliases"):
		return {"valid": false, "mapped": mapped, "missing_required": ["profile/skeleton"],
			"missing_optional": missing_optional, "hierarchy_errors": hierarchy_errors}
	var aliases: Dictionary = profile["aliases"]
	for role in aliases:
		if not aliases[role] is Array:
			continue
		for candidate in aliases[role]:
			var idx: int = skeleton.find_bone(str(candidate))
			if idx >= 0:
				mapped[role] = skeleton.get_bone_name(idx)
				break
	for role in profile.get("required_roles", []):
		if not mapped.has(str(role)):
			missing_required.append(str(role))
	for role in profile.get("optional_roles", []):
		if not mapped.has(str(role)):
			missing_optional.append(str(role))
	for rule in profile.get("ancestor_rules", []):
		if not rule is Array or rule.size() != 2:
			continue
		var ancestor_role: String = str(rule[0])
		var child_role: String = str(rule[1])
		if not mapped.has(ancestor_role) or not mapped.has(child_role):
			continue
		var ancestor: int = skeleton.find_bone(str(mapped[ancestor_role]))
		var cursor: int = skeleton.get_bone_parent(skeleton.find_bone(str(mapped[child_role])))
		var matched: bool = false
		while cursor >= 0:
			if cursor == ancestor:
				matched = true
				break
			cursor = skeleton.get_bone_parent(cursor)
		if not matched:
			hierarchy_errors.append("%s must be above %s" % [ancestor_role, child_role])
	return {"valid": missing_required.is_empty() and hierarchy_errors.is_empty(),
		"mapped": mapped, "missing_required": missing_required,
		"missing_optional": missing_optional, "hierarchy_errors": hierarchy_errors,
		"bone_count": skeleton.get_bone_count(), "profile": str(profile.get("id", "unknown"))}


static func bone_for_socket(mapping: Dictionary, profile: Dictionary, socket_name: String) -> String:
	var sockets: Dictionary = profile.get("sockets", {})
	if not sockets.has(socket_name):
		return ""
	for role in sockets[socket_name]:
		if mapping.has(str(role)):
			return str(mapping[str(role)])
	return ""
