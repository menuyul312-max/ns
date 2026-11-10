extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var visual := CharacterRigVisual.new()
	actor.add_child(visual)
	visual.setup()
	if not visual.imported_glb:
		_fail("real user model required")
		return
	var animator := SkeletonAnimationBridge.new()
	actor.add_child(animator)
	animator.setup(actor, visual)
	if not animator.initialized:
		_fail("AnimationTree did not initialize")
		return
	if SkeletonAnimationBridge.CLIPS.size() + SkeletonAnimationBridge.ACTION_CLIPS.size() != 16:
		_fail("catalog should expose 16 reusable prototype motions")
		return
	for name in SkeletonAnimationBridge.CLIPS + SkeletonAnimationBridge.ACTION_CLIPS:
		if not animator.animation_player.has_animation(name):
			_fail("missing animation " + name)
			return
	animator.travel("run")
	for _i in range(12):
		await physics_frame
	if str(animator.playback.get_current_node()) != "run":
		_fail("run locomotion state not reached")
		return
	if not animator.fire_action("wave") or animator.fire_action("clap"):
		_fail("action fired twice or rejected")
		return
	for _i in range(6):
		await physics_frame
	if not bool(animator.animation_tree.get("parameters/action/active")):
		_fail("upper-body OneShot not active")
		return
	if animator.current_clip != "run":
		_fail("wave action interrupted locomotion state")
		return
	if animator.action_node.animation != &"wave":
		_fail("OneShot did not select wave animation")
		return
	for _i in range(80):
		await physics_frame
	if not animator.fire_action("clap"):
		_fail("cooldown did not release action after wave")
		return
	print("PASS — 16 prototype clips, run locomotion, wave/clap OneShot layering")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
