extends SceneTree
## Samples the real Godot AnimationPlayer tracks from Character Base Kit v1.
## This makes an offline Blender video agree with the Godot-authored bone poses.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := Node3D.new()
	actor.name = "NusaMotionExportActor"
	root.add_child(actor)
	var rig := CharacterRigVisual.new()
	actor.add_child(rig)
	rig.setup()
	if not rig.imported_glb:
		push_error("Motion export requires the user-owned GLB at res://assets/character_nusantara.glb")
		quit(1)
		return
	var animator := SkeletonAnimationBridge.new()
	actor.add_child(animator)
	animator.setup(actor, rig)
	if not animator.initialized:
		push_error("AnimationPlayer/AnimationTree setup failed")
		quit(2)
		return
	# Direct AnimationPlayer sampling isolates every authored prototype clip; the
	# game still uses AnimationTree state/OneShot layering during gameplay.
	animator.animation_tree.active = false
	var skeleton: Skeleton3D = rig.skeleton
	var bone_names: Array[String] = []
	var rest: Array[Array] = []
	for bone_id in skeleton.get_bone_count():
		bone_names.append(skeleton.get_bone_name(bone_id))
		rest.append(_pack_transform(skeleton.get_bone_global_rest(bone_id)))
	var sample_rate: int = 12
	var json_clips: Array[Dictionary] = []
	for clip_name in SkeletonAnimationBridge.CLIPS + SkeletonAnimationBridge.ACTION_CLIPS:
		var animation: Animation = animator.animation_player.get_animation(clip_name)
		if animation == null:
			push_error("Missing animation clip: " + clip_name)
			quit(3)
			return
		var sample_count: int = ceili(animation.length * float(sample_rate))
		var frames: Array[Dictionary] = []
		animator.animation_player.play(clip_name)
		animator.animation_player.advance(0.0)
		for frame_number in sample_count:
			var seconds: float = minf(float(frame_number) / float(sample_rate), animation.length - 0.00001)
			animator.animation_player.seek(seconds, true)
			skeleton.force_update_all_bone_transforms()
			var poses: Array[Array] = []
			for bone_id in skeleton.get_bone_count():
				poses.append(_pack_transform(skeleton.get_bone_global_pose(bone_id)))
			frames.append({"time": snappedf(seconds, 0.00001), "pose": poses})
		animator.animation_player.stop()
		skeleton.reset_bone_poses()
		json_clips.append({"name": clip_name, "duration": animation.length, "frames": frames})
		print("EXPORTED ", clip_name, " / ", frames.size(), " actual Godot skeleton poses")
	var document: Dictionary = {
		"schema": "nusa_motion_samples_v1",
		"source": "Godot 4.7 AnimationPlayer, original 23-joint user character",
		"fps": sample_rate,
		"bones": bone_names,
		"rest_global": rest,
		"clips": json_clips
	}
	var filepath: String = OS.get_environment("NUSA_MOTION_SAMPLES")
	if filepath.is_empty():
		filepath = ProjectSettings.globalize_path("res://generated/nusa_animation_samples.json")
	DirAccess.make_dir_recursive_absolute(filepath.get_base_dir())
	var output := FileAccess.open(filepath, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write samples: " + filepath)
		quit(4)
		return
	output.store_string(JSON.stringify(document))
	output.close()
	print("NUSA_MOTION_EXPORT ", filepath, " clips=", json_clips.size(), " bones=", bone_names.size())
	quit(0)


func _pack_transform(transform: Transform3D) -> Array[float]:
	var q: Quaternion = transform.basis.get_rotation_quaternion()
	var p: Vector3 = transform.origin
	return [q.x, q.y, q.z, q.w, p.x, p.y, p.z]
