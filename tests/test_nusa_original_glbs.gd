extends SceneTree
## Optional local acceptance smoke for FIVE private user GLBs exported by
## tools/rig_nusa_original_glbs.py. Input/output meshes stay out of git.

const TARGETS := [
	["chr_bahari_s3", "humanoid", "bahari", 21, 16],
	["chr_lintang_s3", "humanoid", "lintang", 25, 16],
	["elder_gajah_s3", "humanoid", "gajah", 25, 16],
	["elder_gurita_s3", "octopus", "gurita", 18, 6],
	["elder_komo_s3", "animal_biped", "komo", 24, 16],
]


func _initialize() -> void:
	call_deferred("_run")


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null


func _run() -> void:
	for config in TARGETS:
		var stem: String = config[0]
		var species: String = config[2]
		var path: String = "res://generated/private_originals/%s_rigged.glb" % stem
		if not ResourceLoader.exists(path):
			_fail("run private auto-rig generator first; missing " + path)
			return
		var profile: String = "res://data/characters/profiles/%s.json" % config[1]
		var wrapper := CharacterRigVisual.new()
		wrapper.configure_asset(path, profile, 1.0, Vector3.ZERO, "")
		root.add_child(wrapper)
		wrapper.setup()
		if not wrapper.imported_glb or wrapper.skeleton == null:
			_fail("Godot failed to import original skinned " + species)
			return
		if wrapper.skeleton.get_bone_count() != int(config[3]):
			_fail("wrong Godot bone count for " + species)
			return
		var report: Dictionary = wrapper.rig_report
		if not bool(report.get("valid", false)):
			_fail("invalid skeleton profile for " + species + ": " + str(report))
			return
		var anim: AnimationPlayer = _find_animation_player(wrapper)
		if anim == null:
			_fail("missing AnimationPlayer for " + species)
			return
		var clips: PackedStringArray = anim.get_animation_list()
		if clips.size() != int(config[4]):
			_fail("expected %d clips for %s, found %s" % [int(config[4]), species, str(clips)])
			return
		var expected: String = "swim" if species == "gurita" else "walk"
		if not anim.has_animation(expected):
			_fail("missing %s animation in %s" % [expected, species])
			return
		var collider: Dictionary = NusaCollisionProfile.load_profile(
			"res://data/characters/collisions/%s.json" % species)
		if collider.is_empty() or float(collider.get("radius", 0.0)) <= 0.0:
			_fail("missing/invalid species collision " + species)
			return
		if wrapper.face_atlas != null:
			_fail("original baked face should not get a duplicate projected eye atlas: " + species)
			return
		var moving_role: String = "Tentacle01Base" if species == "gurita" else "Leg_L"
		var bone: int = wrapper.skeleton.find_bone(str(wrapper.bones[moving_role]))
		anim.play(expected)
		anim.advance(0.0)
		var first: Quaternion = wrapper.skeleton.get_bone_pose_rotation(bone)
		anim.seek(0.3, true)
		var second: Quaternion = wrapper.skeleton.get_bone_pose_rotation(bone)
		if first.angle_to(second) < 0.02:
			_fail("animation doesn't deform requested joint in Godot: " + species)
			return
		var actor := NusaOriginalActor.new()
		actor.species = species
		root.add_child(actor)
		if actor.body_shape == null or actor.interaction_area == null:
			_fail("original actor lacks physics capsule or interaction area: " + species)
			return
		if not actor.character_visual.imported_glb or not actor.play_clip(expected):
			_fail("species actor failed to display and animate its original GLB: " + species)
			return
		var capsule: CapsuleShape3D = actor.body_shape.shape as CapsuleShape3D
		if capsule == null or absf(capsule.radius - float(collider["radius"])) > 0.001:
			_fail("real body collider doesn't match profile: " + species)
			return
		print("NUSA_IMPORTED_ORIGINAL", species, "bones=", wrapper.skeleton.get_bone_count(),
			"clips=", clips.size(), "radius=", float(collider["radius"]))
		wrapper.queue_free()
		actor.queue_free()
	print("PASS — all 5 original meshes are skinned, animated, species-profiled and imported by Godot")
	quit(0)


func _fail(reason: String) -> void:
	push_error("FAIL — " + reason)
	quit(1)
