class_name MannequinAnimationBridge
extends Node
## Stand-in clip/AnimationTree adapter. It animates lab pivots until a real GLB
## skeleton and authored animation clips are supplied by the character pipeline.

const CLIPS: Array[String] = ["idle", "walk", "wade", "swim"]
const CLIP_LENGTH: float = 1.0

var actor: Node3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var current_clip: String = "idle"
var initialized: bool = false


func setup(lab_actor: Node3D) -> void:
	actor = lab_actor
	animation_player = AnimationPlayer.new()
	animation_player.name = "MotionClips"
	animation_player.root_node = NodePath("../..")
	add_child(animation_player)
	var library := AnimationLibrary.new()
	for clip_name in CLIPS:
		library.add_animation(clip_name, _make_clip(clip_name))
	animation_player.add_animation_library("", library)
	var machine := AnimationNodeStateMachine.new()
	for clip_name in CLIPS:
		var node := AnimationNodeAnimation.new()
		node.animation = StringName(clip_name)
		machine.add_node(StringName(clip_name), node)
	for source in CLIPS:
		for destination in CLIPS:
			if source == destination:
				continue
			var edge := AnimationNodeStateMachineTransition.new()
			edge.xfade_time = 0.18
			machine.add_transition(StringName(source), StringName(destination), edge)
	var start_edge := AnimationNodeStateMachineTransition.new()
	machine.add_transition(&"Start", &"idle", start_edge)
	animation_tree = AnimationTree.new()
	animation_tree.name = "MotionTree"
	animation_tree.anim_player = NodePath("../MotionClips")
	animation_tree.tree_root = machine
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	add_child(animation_tree)
	animation_tree.active = true
	playback = animation_tree.get("parameters/playback")
	if playback != null:
		playback.travel("idle")
	initialized = true


func travel(state_name: String) -> void:
	var target: String = state_name.to_lower()
	# Keep the HUD's Indonesian state labels separate from clip identifiers.
	match target:
		"diam": target = "idle"
		"jalan": target = "walk"
		"rendam": target = "wade"
		"renang": target = "swim"
	if not initialized or playback == null or not CLIPS.has(target) or target == current_clip:
		return
	current_clip = target
	playback.travel(StringName(target))


func _make_clip(clip_name: String) -> Animation:
	var clip := Animation.new()
	clip.length = CLIP_LENGTH
	clip.loop_mode = Animation.LOOP_LINEAR
	var steps: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	for index in range(2):
		var arm: Node3D = actor.arm_joints[index]
		var leg: Node3D = actor.leg_joints[index]
		var arm_path := NodePath(str(actor.get_path_to(arm)) + ":rotation")
		var leg_path := NodePath(str(actor.get_path_to(leg)) + ":rotation")
		var arm_track: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(arm_track, arm_path)
		var leg_track: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(leg_track, leg_path)
		for t in steps:
			var cycle: float = sin(TAU * t + float(index) * PI)
			var opposite: float = sin(TAU * t + float(index) * PI + PI)
			var arm_angle: float = 0.0
			var leg_angle: float = 0.0
			var arm_open: float = 0.0
			match clip_name:
				"idle":
					arm_angle = 0.018 * cycle
				"walk":
					arm_angle = 0.52 * cycle
					leg_angle = 0.53 * opposite
				"wade":
					arm_angle = 0.31 * cycle
					leg_angle = 0.25 * opposite
					arm_open = 0.16
				"swim":
					arm_angle = 0.84 * cycle
					leg_angle = 0.47 * opposite
					arm_open = 0.38
			var outward: float = -1.0 if index == 0 else 1.0
			clip.track_insert_key(arm_track, t, Vector3(arm_angle, 0.0, arm_open * outward))
			clip.track_insert_key(leg_track, t, Vector3(leg_angle, 0.0, 0.0))
	var head: MeshInstance3D = actor.head_mesh
	var head_track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(head_track, NodePath(str(actor.get_path_to(head)) + ":position"))
	for t in steps:
		var bounce: float = 0.006 if clip_name == "idle" else (0.022 if clip_name == "walk" else (0.014 if clip_name == "wade" else 0.018))
		clip.track_insert_key(head_track, t, Vector3(0.0, 0.32 + bounce * sin(TAU * t), -0.006))
	return clip
