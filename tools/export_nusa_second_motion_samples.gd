extends SceneTree
## Render pipeline fixture: sample all source clips after retargeting them into
## the generated *different* 26-bone biped. JSON is consumed by the unchanged
## tools/render_nusa_motion.py Blender renderer.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_actor := Node3D.new()
	root.add_child(source_actor)
	var source := CharacterRigVisual.new()
	source_actor.add_child(source)
	source.setup()
	var target := CharacterRigVisual.new()
	target.configure_asset("res://generated/nusa_animal_biped_probe.glb",
		"res://data/characters/profiles/animal_biped.json", 1.0, Vector3.ZERO,
		"res://data/characters/face_profiles/animal_biped_probe.json")
	root.add_child(target)
	target.setup()
	if not source.imported_glb or not target.imported_glb:
		push_error("Both imported skinned GLBs are needed before sampling")
		quit(1)
		return
	var animator := SkeletonAnimationBridge.new()
	source_actor.add_child(animator)
	animator.setup(source_actor, source)
	animator.animation_tree.active = false
	var retarget := NusaRetargetPlayback.new()
	if not retarget.setup(animator.animation_player, source.skeleton, target.skeleton,
		NusaRigProfile.load_profile(), NusaRigProfile.load_profile(
			"res://data/characters/profiles/animal_biped.json")):
		push_error("Generated animal rig is not compatible with biped retarget")
		quit(2)
		return
	var skeleton: Skeleton3D = target.skeleton
	var bone_names: Array[String] = []
	var rest: Array[Array] = []
	for bone_id in skeleton.get_bone_count():
		bone_names.append(skeleton.get_bone_name(bone_id))
		rest.append(_pack_transform(skeleton.get_bone_global_rest(bone_id)))
	var fps: int = 12
	var clips: Array[Dictionary] = []
	for name in SkeletonAnimationBridge.CLIPS + SkeletonAnimationBridge.ACTION_CLIPS:
		var clip: Animation = animator.animation_player.get_animation(name)
		if not retarget.play(name):
			push_error("Cannot sample " + name)
			quit(3)
			return
		var frames: Array[Dictionary] = []
		for frame in ceili(clip.length * fps):
			var time: float = float(frame) / float(fps)
			var report: Dictionary = retarget.sample(time)
			if not report.get("valid", false):
				push_error("Retarget failed " + name)
				quit(4)
				return
			var poses: Array[Array] = []
			for bone_id in skeleton.get_bone_count():
				poses.append(_pack_transform(skeleton.get_bone_global_pose(bone_id)))
			frames.append({"time": snappedf(time, 0.00001), "pose": poses})
		clips.append({"name": name, "duration": clip.length, "frames": frames})
		print("NUSA_SECOND_RETARGET ", name, " ", frames.size(), " frames")
	var path: String = OS.get_environment("NUSA_SECOND_MOTION_SAMPLES")
	if path.is_empty():
		path = ProjectSettings.globalize_path("res://generated/nusa_second_motion_samples.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		quit(5)
		return
	file.store_string(JSON.stringify({"schema": "nusa_motion_samples_v1",
		"source": "Godot sampled 23-bone source -> 26-bone Nusa original animal fixture via rest-axis retarget",
		"fps": fps, "bones": bone_names, "rest_global": rest,
		"clips": clips}))
	file.close()
	print("PASS — 16 clips sampled to 26-bone animal ", path)
	quit(0)


func _pack_transform(transform: Transform3D) -> Array[float]:
	var q: Quaternion = transform.basis.get_rotation_quaternion()
	var p: Vector3 = transform.origin
	return [q.x, q.y, q.z, q.w, p.x, p.y, p.z]
