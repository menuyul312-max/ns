extends SceneTree
## Dedicated Godot acceptance test for the one-character refinement sprint.

const MODEL := "res://generated/komo_v41_rigged/elder_komo_clean_paint_rigged.glb"
const CLIPS := ["idle", "walk", "run", "turn", "start_stop", "sit", "wade",
	"swim", "shovel", "pickup", "carry", "interact", "watering", "talk",
	"wave", "clap"]
const EXPRESSIONS := ["neutral", "blink", "blink_left", "blink_right", "happy",
	"sad", "angry", "surprised", "look_left", "look_right", "talk_a", "talk_o"]


func _initialize() -> void:
	call_deferred("_test")


func _test() -> void:
	if not ResourceLoader.exists(MODEL):
		push_error("Import the polished Komo GLB in Godot editor first: " + MODEL)
		quit(1)
		return
	var root := Node3D.new()
	root.name = "KomoAcceptanceWorld"
	get_root().add_child(root)
	var actor := NusaOriginalActor.new()
	actor.species = "komo"
	actor.visual_resource_override = MODEL
	root.add_child(actor)
	var errors: Array[String] = []
	if actor.character_visual == null or not actor.character_visual.imported_glb:
		errors.append("Polished model did not import")
	if actor.character_visual == null or actor.character_visual.skeleton == null:
		errors.append("Missing Skeleton3D")
	if actor.komo_face == null:
		errors.append("Independent face not attached to Head")
	if actor.body_shape == null or actor.interaction_area == null:
		errors.append("Missing independent body/interaction collisions")
	if actor.animation_player == null:
		errors.append("Missing animation player")
	else:
		for clip in CLIPS:
			if not actor.animation_player.has_animation(clip):
				errors.append("Missing clip " + clip)
	if actor.komo_face != null:
		for expression in EXPRESSIONS:
			if not actor.set_expression(expression):
				errors.append("Unplayable expression " + expression)
		actor.set_expression("blink_left")
		if actor.komo_face.left_atlas.region == actor.komo_face.right_atlas.region:
			errors.append("Left blink must not close right eye")
		actor.set_expression("neutral")
		if actor.komo_face.face_plate == null:
			errors.append("Missing rounded corrective face surface")
		if not actor.play_clip("talk"):
			errors.append("Talk clip not playable")
		else:
			actor._process(.2)
			if actor.komo_face.mouth_atlas.region.position.x != 4 * 64:
				errors.append("Talk clip did not cycle to the O mouth phoneme")
		actor.play_clip("idle")
		actor._process(3.6)
		if actor.komo_face.left_atlas.region.position.x != 1 * 64:
			errors.append("Idle automatic blink failed")
		actor._process(.12)
		if actor.komo_face.left_atlas.region.position.x != 0:
			errors.append("Idle eye did not reopen after blink")
	if errors.is_empty():
		print("KOMO_V4_PASS bones=", actor.character_visual.skeleton.get_bone_count(),
			" clips=", CLIPS.size(), " face_presets=", EXPRESSIONS.size(),
			" separate_eye_layers=2 collision=body+interaction")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)
