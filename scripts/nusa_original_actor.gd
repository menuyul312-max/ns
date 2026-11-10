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

@export_enum("bahari", "lintang", "gajah", "gurita", "komo") var species: String = "komo"
@export var visual_scale: float = 1.0
@export var visual_offset: Vector3 = Vector3.ZERO
@export var movement_speed: float = 1.65
@export var gravity_strength: float = 16.0

var character_visual: CharacterRigVisual
var animation_player: AnimationPlayer
var body_shape: CollisionShape3D
var interaction_area: Area3D
var collision_profile: Dictionary = {}
var movement_axis: Vector2 = Vector2.ZERO


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
	character_visual.configure_asset("res://generated/private_originals/%s_rigged.glb" % entry[0],
		"res://data/characters/profiles/%s.json" % entry[1],
		visual_scale, visual_offset, "")
	add_child(character_visual)
	character_visual.setup()
	if not character_visual.imported_glb:
		push_error("Run tools/rig_nusa_original_glbs.py to build " + species)
		return
	animation_player = _find_player(character_visual)
	play_clip("idle")


func set_movement_axis(axis: Vector2) -> void:
	movement_axis = axis.limit_length()


func play_clip(clip_name: String) -> bool:
	if animation_player == null or not animation_player.has_animation(clip_name):
		return false
	animation_player.play(clip_name)
	return true


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
