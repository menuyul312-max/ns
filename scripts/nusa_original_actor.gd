class_name NusaOriginalActor
extends CharacterBody3D
## A species-agnostic gameplay shell for original Nusa rigged meshes.
## Physics and interaction volumes are independent of the animated skin.

const SPECIES_RESOURCES := {
	"bahari": ["chr_bahari_s3", "humanoid"],
	"lintang": ["chr_lintang_s3", "humanoid"],
	"gajah": ["elder_gajah_s3", "humanoid"],
	"gurita": ["elder_gurita_s3", "octopus"],
	"komo": ["elder_komo_s3", "animal_biped"],
}
const KOMO_CLIP_EXPRESSIONS := {
	"idle": "neutral", "walk": "neutral", "run": "happy",
	"turn": "look_left", "start_stop": "neutral", "sit": "happy",
	"wade": "surprised", "swim": "happy", "shovel": "angry",
	"pickup": "surprised", "carry": "neutral", "interact": "talk_a",
	"watering": "happy", "talk": "talk_a", "wave": "happy", "clap": "happy",
}

@export_enum("bahari", "lintang", "gajah", "gurita", "komo") var species: String = "komo"
@export var visual_scale: float = 1.0
@export var visual_offset: Vector3 = Vector3.ZERO
@export_file("*.glb") var visual_resource_override: String = ""
@export var movement_speed: float = 1.65
@export var gravity_strength: float = 16.0

var character_visual: CharacterRigVisual
var animation_player: AnimationPlayer
var body_shape: CollisionShape3D
var interaction_area: Area3D
var komo_face: NusaKomoFace
var collision_profile: Dictionary = {}
var movement_axis: Vector2 = Vector2.ZERO
var _komo_expression_base: String = "neutral"
var _komo_blink_wait: float = 3.5
var _komo_blink_remaining: float = 0.0
var _komo_speech_phase: float = 0.0


func _ready() -> void:
	if not SPECIES_RESOURCES.has(species):
		push_error("Unknown Nusa species: " + species)
		return
	var entry: Array = SPECIES_RESOURCES[species]
	collision_profile = NusaCollisionProfile.load_profile(
		"res://data/characters/collisions/%s.json" % species)
	if collision_profile.is_empty():
		push_error("Nusa collision profile missing: " + species)
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(collision_profile["radius"])
	capsule.height = float(collision_profile["height"])
	body_shape = CollisionShape3D.new()
	body_shape.name = "BodyCollision"
	body_shape.shape = capsule
	add_child(body_shape)
	collision_layer = int(collision_profile.get("body_layer", 4))
	collision_mask = int(collision_profile.get("world_mask", 49))
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionReach"
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = int(collision_profile.get("interaction_mask", 16))
	add_child(interaction_area)
	var reach_shape := CollisionShape3D.new()
	reach_shape.name = "ReachVolume"
	var reach := SphereShape3D.new()
	reach.radius = float(collision_profile["interaction_radius"])
	reach_shape.shape = reach
	reach_shape.position = Vector3(0, float(collision_profile["interaction_height"]),
		-float(collision_profile["interaction_forward"]))
	interaction_area.add_child(reach_shape)
	character_visual = CharacterRigVisual.new()
	character_visual.name = "CharacterVisual"
	var requested_glb: String = visual_resource_override if not visual_resource_override.is_empty() else (
		"res://generated/private_originals/%s_rigged.glb" % entry[0])
	character_visual.configure_asset(requested_glb,
		"res://data/characters/profiles/%s.json" % entry[1],
		visual_scale, visual_offset, "")
	add_child(character_visual)
	character_visual.setup()
	if not character_visual.imported_glb:
		push_error("Run tools/rig_nusa_original_glbs.py to build " + species)
		return
	if species == "komo":
		_attach_komo_face()
	animation_player = _find_player(character_visual)
	play_clip("idle")


func _attach_komo_face() -> void:
	var skeleton: Skeleton3D = character_visual.skeleton
	var head_idx: int = skeleton.find_bone("Head")
	if head_idx < 0:
		push_error("Komo head bone not found")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "KomoTextureFaceHeadAttachment"
	attachment.bone_name = &"Head"
	skeleton.add_child(attachment)
	attachment.transform = skeleton.get_bone_global_rest(head_idx).affine_inverse()
	komo_face = NusaKomoFace.new()
	komo_face.name = "KomoTextureFace"
	attachment.add_child(komo_face)
	komo_face.setup(visual_resource_override.is_empty())


func set_expression(expression: String) -> bool:
	if komo_face == null:
		return false
	if not komo_face.set_expression(expression):
		return false
	_komo_expression_base = expression
	_komo_blink_remaining = 0.0
	return true


func set_movement_axis(axis: Vector2) -> void:
	movement_axis = axis.limit_length()


func play_clip(clip_name: String) -> bool:
	if animation_player == null or not animation_player.has_animation(clip_name):
		return false
	animation_player.play(clip_name)
	if komo_face != null and KOMO_CLIP_EXPRESSIONS.has(clip_name):
		set_expression(KOMO_CLIP_EXPRESSIONS[clip_name])
		_komo_speech_phase = 0.0
	return true


func _process(delta: float) -> void:
	if komo_face == null or animation_player == null:
		return
	if animation_player.current_animation in [&"talk", &"interact"]:
		_komo_speech_phase += delta
		komo_face.set_mouth_state("talk_o" if fmod(_komo_speech_phase, .32) >= .16 else "talk_a")
	else:
		_komo_speech_phase = 0.0
	# Short independent eyelid event, leaving the chosen expression unchanged.
	if _komo_blink_remaining > 0.0:
		_komo_blink_remaining -= delta
		if _komo_blink_remaining <= 0.0:
			komo_face.set_expression(_komo_expression_base)
	elif _komo_expression_base in ["neutral", "happy", "sad", "talk_a", "talk_o"]:
		_komo_blink_wait -= delta
		if _komo_blink_wait <= 0.0:
			komo_face.set_eye_state("left", "blink")
			komo_face.set_eye_state("right", "blink")
			_komo_blink_remaining = .11
			_komo_blink_wait = 2.8 + randf_range(0.0, 1.8)


func _physics_process(delta: float) -> void:
	if collision_profile.is_empty():
		return
	velocity.x = movement_axis.x * movement_speed
	velocity.z = movement_axis.y * movement_speed
	velocity.y = maxf(velocity.y - gravity_strength * delta, -20.0) if not is_on_floor() else 0.0
	move_and_slide()


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found:
			return found
	return null
