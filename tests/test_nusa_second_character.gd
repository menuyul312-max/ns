extends SceneTree
## End-to-end portability fixture: imported 23-bone source -> imported
## 26-bone animal with different rest orientation, independent face and collider.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_path: String = "res://generated/nusa_animal_biped_probe.glb"
	if not ResourceLoader.exists(fixture_path):
		_fail("generate second creature GLB with tools/make_nusa_animal_biped_probe.py")
		return
	var original_actor := Node3D.new()
	root.add_child(original_actor)
	var original := CharacterRigVisual.new()
	original_actor.add_child(original)
	original.setup()
	if not original.imported_glb:
		_fail("source user-owned 23-bone GLB not imported")
		return
	var target := CharacterRigVisual.new()
	target.configure_asset(fixture_path, "res://data/characters/profiles/animal_biped.json",
		1.0, Vector3.ZERO, "res://data/characters/face_profiles/animal_biped_probe.json")
	root.add_child(target)
	target.setup()
	if not target.imported_glb or target.skeleton.get_bone_count() != 26:
		_fail("26-bone generated animal GLB import/skin failed: " + str(target.rig_report))
		return
	if not target.bones.has("Tail") or not target.bones.has("Ear_L") or not target.bones.has("Muzzle"):
		_fail("animal-specific bone mapping is missing tail/ear/muzzle")
		return
	if target.face_atlas == null or not target.set_expression("happy"):
		_fail("target creature did not get a separate facial texture layer")
		return
	if target.face_atlas.eye_atlas.region.position.x != 4 * NusaFaceAtlas.EYE_WIDTH:
		_fail("target creature facial expression did not change")
		return

	var controller := SkeletonAnimationBridge.new()
	original_actor.add_child(controller)
	controller.setup(original_actor, original)
	controller.animation_tree.active = false
	var source_profile: Dictionary = NusaRigProfile.load_profile()
	var target_profile: Dictionary = NusaRigProfile.load_profile(
		"res://data/characters/profiles/animal_biped.json")
	var playback := NusaRetargetPlayback.new()
	if not playback.setup(controller.animation_player, original.skeleton,
			target.skeleton, source_profile, target_profile):
		_fail("retarget playback plan incompatible with second creature")
		return
	var tail: int = target.skeleton.find_bone(str(target.bones["Tail"]))
	var unchanged_tail: Quaternion = target.skeleton.get_bone_pose_rotation(tail)
	var right_arm: int = target.skeleton.find_bone(str(target.bones["Arm_R"]))
	var right_arm_base: Quaternion = target.skeleton.get_bone_pose_rotation(right_arm)
	if not playback.play("idle"):
		_fail("retarget playback needs a neutral reference clip")
		return
	playback.sample(0.0)
	if target.skeleton.get_bone_pose_rotation(right_arm).angle_to(right_arm_base) > 0.002:
		_fail("retargeted neutral pose twisted the target shoulder away from its authored rest")
		return
	var names: Array[String] = SkeletonAnimationBridge.CLIPS + SkeletonAnimationBridge.ACTION_CLIPS
	for clip in names:
		if not playback.play(clip):
			_fail("source clip missing " + clip)
			return
		var report: Dictionary = playback.sample(0.26)
		if not report.get("valid", false) or report["copied"].size() < 7:
			_fail("retarget failed clip " + clip + " mapped " + str(report))
			return
	if not playback.play("walk"):
		_fail("could not restart walk")
		return
	playback.sample(0.0)
	var left_leg: int = target.skeleton.find_bone(str(target.bones["Leg_L"]))
	var first: Quaternion = target.skeleton.get_bone_pose_rotation(left_leg)
	playback.sample(0.25)
	var swing: Quaternion = target.skeleton.get_bone_pose_rotation(left_leg)
	if first.angle_to(swing) < 0.03:
		_fail("walk failed to articulate second character thigh")
		return
	if target.skeleton.get_bone_pose_rotation(tail).angle_to(unchanged_tail) > 0.001:
		_fail("non-shared species tail should remain untouched by humanoid animation")
		return

	var actor := RiverCharacter.new()
	actor.collision_profile_path = "res://data/characters/collisions/animal_biped.json"
	actor.character_model_path = fixture_path
	actor.character_rig_profile_path = "res://data/characters/profiles/animal_biped.json"
	actor.character_face_profile_path = "res://data/characters/face_profiles/animal_biped_probe.json"
	actor.character_visual_scale = 1.0
	root.add_child(actor)
	var capsule: CapsuleShape3D = actor.body_collision.shape as CapsuleShape3D
	if capsule == null or absf(capsule.radius - 0.25) > 0.001:
		_fail("second creature needs its own body capsule profile")
		return
	if actor.interaction_reach == null or actor.interaction_reach.collision_mask != 16:
		_fail("second creature needs an independent interaction sensor")
		return
	if not actor.rig_visual.imported_glb or actor.rig_visual.skeleton.get_bone_count() != 26:
		_fail("RiverCharacter should actually display the selected animal rig, not the human")
		return
	if actor.rig_visual.face_atlas == null:
		_fail("selected animal rig should carry the animal-specific face profile")
		return
	print("PASS — second rig: 26-bone animal GLB, 16 retargeted clips, animated thigh, head face atlas, tail role, species collision")
	quit(0)


func _fail(reason: String) -> void:
	push_error("FAIL — " + reason)
	quit(1)
