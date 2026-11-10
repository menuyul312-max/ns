extends SceneTree
## Tests functional texture regions and independent eye/mouth animation.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig := CharacterRigVisual.new()
	root.add_child(rig)
	rig.setup()
	if not rig.imported_glb or rig.face_atlas == null:
		_fail("default user GLB did not create texture-driven face")
		return
	var face: NusaFaceAtlas = rig.face_atlas
	if face.eye_sprite == null or face.mouth_sprite == null:
		_fail("eyes and mouth are not separate Sprite3D layers")
		return
	if not rig.set_expression("happy", 0.01):
		_fail("hybrid expression not accepted")
		return
	if face.eye_atlas.region.position.x != 4 * NusaFaceAtlas.EYE_WIDTH or face.mouth_atlas.region.position.x != NusaFaceAtlas.MOUTH_WIDTH:
		_fail("atlas regions not switched for happy")
		return
	if not rig.set_expression("blink_left", 0.01):
		_fail("individual blink texture not supported")
		return
	if face.eye_atlas.region.position.x != 2 * NusaFaceAtlas.EYE_WIDTH:
		_fail("left-eye independent blink not selected")
		return
	if not rig.set_expression("neutral", 0.01):
		_fail("neutral texture not supported")
		return
	if face.eye_atlas.region.position.x != 0 or face.mouth_atlas.region.position.x != 0:
		_fail("neutral did not restore both texture channels")
		return
	if not rig.face_controller.suppress_mouth_morphs:
		_fail("legacy mouth morphs should be disabled under the texture face")
		return
	var attachment: BoneAttachment3D = face.get_parent() as BoneAttachment3D
	if attachment == null or str(attachment.bone_name) != "Head":
		_fail("face texture should follow the real head bone")
		return
	# Uploaded GLB faces +Z in Godot (+Z becomes Blender -Y). An older
	# negative-Z face coordinate rendered on the back of this model's head.
	var face_rest: Vector3 = rig.skeleton.get_bone_global_rest(
		rig.skeleton.find_bone(str(rig.bones["Head"]))).origin
	var neutral_point: Vector3 = rig.skeleton.get_bone_global_rest(
		rig.skeleton.find_bone(str(rig.bones["Head"]))) * face.transform.origin
	if neutral_point.z <= face_rest.z:
		_fail("configured GLB face must be in front of the head (+Z)")
		return
	var output_dir: String = OS.get_environment("NUSA_FACE_ATLAS_DIR")
	if not output_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(output_dir)
		face.eye_atlas.atlas.get_image().save_png(output_dir.path_join("nusa_eyes_atlas.png"))
		face.mouth_atlas.atlas.get_image().save_png(output_dir.path_join("nusa_mouth_atlas.png"))
	print("PASS — Nusa face v2: independent texture layers, eye variants, mouth variants, morph fallback and head socket")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
