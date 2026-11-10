class_name SkeletonAnimationBridge
extends Node
## AnimationTree clips controlling Skeleton3D bones, not manually rotated pivots.

const CLIPS: Array[String] = ["idle", "walk", "run", "turn", "start_stop", "sit", "wade", "swim"]
const ACTION_CLIPS: Array[String] = ["shovel", "pickup", "carry", "interact", "watering", "talk", "wave", "clap"]
const CLIP_LENGTH: float = 1.0
const SHOVEL_DURATION: float = 1.30

var skeleton: Skeleton3D
var bone_names: Dictionary = {}
var imported_rig: bool = false
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var current_clip: String = "idle"
var initialized: bool = false
var shovel_remaining: float = 0.0
var shovel_elapsed: float = 0.0
var shovel_count: int = 0
var action_node: AnimationNodeAnimation
var action_remaining: float = 0.0
var current_action: String = ""


func setup(actor: Node3D, target_rig: CharacterRigVisual) -> void:
	skeleton = target_rig.skeleton
	bone_names = target_rig.bones.duplicate()
	imported_rig = target_rig.imported_glb
	if skeleton == null:
		return
	animation_player = AnimationPlayer.new()
	animation_player.name = "SkeletonMotionClips"
	animation_player.root_node = NodePath("../..")
	add_child(animation_player)
	var library := AnimationLibrary.new()
	for clip in CLIPS:
		library.add_animation(clip, _make_clip(actor, clip))
	library.add_animation("shovel", _make_shovel_clip(actor))
	for action in ACTION_CLIPS:
		if action != "shovel":
			library.add_animation(action, _make_action_clip(actor, action))
	animation_player.add_animation_library("", library)
	var machine := AnimationNodeStateMachine.new()
	for clip in CLIPS:
		var node := AnimationNodeAnimation.new()
		node.animation = StringName(clip)
		machine.add_node(StringName(clip), node)
	for origin in CLIPS:
		for destination in CLIPS:
			if origin == destination:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.18
			machine.add_transition(StringName(origin), StringName(destination), transition)
	machine.add_transition(&"Start", &"idle", AnimationNodeStateMachineTransition.new())
	var blend := AnimationNodeBlendTree.new()
	blend.add_node(&"locomotion", machine, Vector2(0, 120))
	action_node = AnimationNodeAnimation.new()
	action_node.animation = &"shovel"
	blend.add_node(&"shovel", action_node, Vector2(0, 320))
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.18
	shot.filter_enabled = true
	for role in ["Arm_L", "Arm_R", "Spine", "Head"]:
		if bone_names.has(role):
			shot.set_filter_path(NodePath(str(actor.get_path_to(skeleton)) + ":" + str(bone_names[role])), true)
	blend.add_node(&"action", shot, Vector2(290, 180))
	blend.connect_node(&"action", 0, &"locomotion")
	blend.connect_node(&"action", 1, &"shovel")
	blend.connect_node(&"output", 0, &"action")
	animation_tree = AnimationTree.new()
	animation_tree.name = "SkeletonMotionTree"
	animation_tree.anim_player = NodePath("../SkeletonMotionClips")
	animation_tree.tree_root = blend
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	add_child(animation_tree)
	animation_tree.active = true
	playback = animation_tree.get("parameters/locomotion/playback")
	if playback != null:
		playback.travel("idle")
		initialized = true


func _physics_process(delta: float) -> void:
	if action_remaining > 0.0:
		action_remaining = maxf(0.0, action_remaining - delta)
		if action_remaining <= 0.0:
			current_action = ""
	if shovel_remaining > 0.0:
		shovel_remaining = maxf(0.0, shovel_remaining - delta)
		shovel_elapsed = SHOVEL_DURATION - shovel_remaining


func fire_shovel() -> bool:
	if not initialized or shovel_remaining > 0.0 or action_remaining > 0.0:
		return false
	action_node.animation = &"shovel"
	shovel_remaining = SHOVEL_DURATION
	shovel_elapsed = 0.0
	shovel_count += 1
	animation_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


func fire_action(action_name: String) -> bool:
	var name: String = action_name.to_lower()
	if name == "shovel":
		return fire_shovel()
	if not initialized or not ACTION_CLIPS.has(name) or action_remaining > 0.0 or shovel_remaining > 0.0:
		return false
	action_node.animation = StringName(name)
	current_action = name
	action_remaining = animation_player.get_animation(name).length
	animation_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return true


func shovel_active() -> bool:
	return shovel_remaining > 0.0


func travel(next_state: String) -> void:
	var target: String = next_state.to_lower()
	match target:
		"diam": target = "idle"
		"jalan": target = "walk"
		"rendam": target = "wade"
		"renang": target = "swim"
	if not initialized or target == current_clip or not CLIPS.has(target):
		return
	current_clip = target
	playback.travel(StringName(target))


func _make_clip(actor: Node3D, clip_name: String) -> Animation:
	var animation := Animation.new()
	animation.length = CLIP_LENGTH
	animation.loop_mode = Animation.LOOP_LINEAR
	var path: String = str(actor.get_path_to(skeleton))
	for role in ["Arm_L", "Arm_R", "Leg_L", "Leg_R", "Head", "Spine"]:
		if not bone_names.has(role):
			continue
		var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath(path + ":" + str(bone_names[role])))
		for step in range(5):
			var moment: float = float(step) * 0.25
			var cycle: float = sin(moment * TAU + (PI if role.ends_with("R") else 0.0))
			var degrees: float = 0.0
			match role:
				"Arm_L", "Arm_R":
					match clip_name:
						"idle": degrees = 0.012 * cycle
						"walk": degrees = 0.54 * cycle
						"run": degrees = 0.83 * cycle
						"turn": degrees = 0.16 * cycle
						"start_stop": degrees = 0.32 * cycle * (1.0 - moment)
						"sit": degrees = -0.16
						"wade": degrees = 0.28 * cycle
						"swim": degrees = 0.79 * cycle
				"Leg_L", "Leg_R":
					match clip_name:
						"walk": degrees = -0.56 * cycle
						"run": degrees = -0.89 * cycle
						"turn": degrees = -0.11 * cycle
						"start_stop": degrees = -0.24 * cycle * (1.0 - moment)
						"sit": degrees = -0.90
						"wade": degrees = -0.24 * cycle
						"swim": degrees = -0.43 * cycle
				"Head":
					degrees = 0.03 * cycle if clip_name == "idle" else 0.07 * cycle
				"Spine":
					degrees = 0.015 * cycle if clip_name != "swim" else 0.09 * cycle
			var quaternion: Quaternion = Quaternion(Vector3.RIGHT, degrees)
			if imported_rig and (role == "Arm_L" or role == "Arm_R"):
				# The uploaded chibi comes in a T-pose. Start with relaxed arms,
				# then apply gait/stroke keyframes in the shoulder's local space.
				var drop_angle: float = 0.65 if clip_name == "swim" else 1.22
				if role == "Arm_R":
					drop_angle *= -1.0
				quaternion = Quaternion(Vector3.FORWARD, drop_angle) * quaternion
			if role == "Head":
				quaternion = Quaternion(Vector3.UP, degrees)
			if imported_rig:
				# The GLB's authored rest rotations include forward/up bone axes.
				# Treat locomotion keys as DELTAS from those rotations. Writing
				# absolute identity rotations inverted both shins and lifted feet
				# ~0.69 m above the island in Sprint 10.
				var bone_index: int = skeleton.find_bone(String(bone_names[role]))
				quaternion = skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion() * quaternion
			animation.rotation_track_insert_key(track, moment, quaternion)
	return animation


func _make_action_clip(actor: Node3D, action_name: String) -> Animation:
	# Reusable, deliberately simple blocking passes. Detailed studio-quality
	# arcs, hand IK and costume simulation remain per-character art tasks.
	var clip := Animation.new()
	clip.length = 1.0
	clip.loop_mode = Animation.LOOP_NONE
	var path: String = str(actor.get_path_to(skeleton))
	var phases: Array[float] = [0.0, 0.2, 0.45, 0.7, 1.0]
	for role in ["Arm_L", "Arm_R", "Forearm_L", "Forearm_R", "Spine", "Head"]:
		if not bone_names.has(role):
			continue
		var track: int = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(path + ":" + str(bone_names[role])))
		for step in range(phases.size()):
			var envelope: float = [0.0, 0.6, 1.0, 0.75, 0.0][step]
			var pitch: float = 0.0
			var lift: float = 0.0
			match action_name:
				"pickup":
					if role == "Spine": pitch = -0.38 * envelope
					elif role.begins_with("Arm_"): pitch = 0.70 * envelope
				"carry":
					if role.begins_with("Arm_"): pitch = -0.60 * envelope
					elif role.begins_with("Forearm_"): pitch = -0.40 * envelope
				"interact":
					if role == "Arm_R": pitch = -0.65 * envelope
				"watering":
					if role == "Arm_R": pitch = -0.93 * envelope
					elif role == "Spine": pitch = -0.16 * envelope
				"talk":
					if role == "Arm_R": pitch = -0.22 * envelope
					elif role == "Head": pitch = 0.10 * envelope
				"wave":
					if role == "Arm_R":
						pitch = -0.35 * envelope
						lift = -1.20 * envelope
					elif role == "Forearm_R": pitch = 0.38 * sin(phases[step] * TAU * 2.0) * envelope
				"clap":
					if role.begins_with("Arm_"): pitch = -0.52 * envelope
					if role == "Arm_L": lift = 0.48 * envelope
					if role == "Arm_R": lift = -0.48 * envelope
			var pose: Quaternion = Quaternion(Vector3.FORWARD, lift) * Quaternion(Vector3.RIGHT, pitch)
			if imported_rig and role.begins_with("Arm_"):
				pose = Quaternion(Vector3.FORWARD, 1.22 if role == "Arm_L" else -1.22) * pose
			if imported_rig:
				var bone_idx: int = skeleton.find_bone(str(bone_names[role]))
				pose = skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion() * pose
			clip.rotation_track_insert_key(track, phases[step], pose)
	return clip


func _make_shovel_clip(actor: Node3D) -> Animation:
	var animation := Animation.new()
	animation.length = SHOVEL_DURATION
	animation.loop_mode = Animation.LOOP_NONE
	var path: String = str(actor.get_path_to(skeleton))
	var times: Array[float] = [0.0, 0.14, 0.34, 0.54, 0.76, 1.06, SHOVEL_DURATION]
	for role in ["Arm_L", "Arm_R", "Spine", "Head"]:
		if not bone_names.has(role):
			continue
		var track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath(path + ":" + str(bone_names[role])))
		for step in range(times.size()):
			var pitch: float = 0.0
			match role:
				"Arm_R": pitch = [0.10, -0.20, -1.03, 1.18, 1.02, 0.16, 0.10][step]
				"Arm_L": pitch = [-0.15, -0.42, -0.74, 0.82, 0.58, -0.22, -0.15][step]
				"Spine": pitch = [0.0, -0.06, -0.15, -0.37, -0.32, -0.06, 0.0][step]
				"Head": pitch = [0.0, 0.03, 0.14, 0.18, 0.11, -0.02, 0.0][step]
			var pose: Quaternion = Quaternion(Vector3.RIGHT, pitch)
			if imported_rig and (role == "Arm_L" or role == "Arm_R"):
				var drop_angle: float = 1.22 if role == "Arm_L" else -1.22
				pose = Quaternion(Vector3.FORWARD, drop_angle) * pose
			if imported_rig:
				var bone_index: int = skeleton.find_bone(String(bone_names[role]))
				pose = skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion() * pose
			animation.rotation_track_insert_key(track, times[step], pose)
	return animation
