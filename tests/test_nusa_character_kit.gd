extends SceneTree
## Tests real GLB source plus reusable profiles, face morphs and sockets.
## Unlike a 3D art audit, this verifies the actual imported Godot hierarchy.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var humanoid: Dictionary = NusaRigProfile.load_profile()
	var animal: Dictionary = NusaRigProfile.load_profile("res://data/characters/profiles/animal_biped.json")
	var winged: Dictionary = NusaRigProfile.load_profile("res://data/characters/profiles/winged_spirit.json")
	var quadruped: Dictionary = NusaRigProfile.load_profile("res://data/characters/profiles/quadruped.json")
	if humanoid.is_empty() or animal.is_empty() or winged.is_empty() or quadruped.is_empty():
		_fail("missing reusable rig profiles")
		return
	if not animal["aliases"].has("Ear_L") or not animal["aliases"].has("Foot_L"):
		_fail("animal profile failed to inherit humanoid roles")
		return
	if not winged["required_roles"].has("Root") or not winged["required_roles"].has("Wing_L"):
		_fail("winged profile must require core body and both wings")
		return
	if quadruped["required_roles"].has("Leg_L") or not quadruped["required_roles"].has("HindLeg_L"):
		_fail("quadruped must have independent four-legged anatomy")
		return
	var rig := CharacterRigVisual.new()
	root.add_child(rig)
	rig.setup()
	if not rig.imported_glb or rig.skeleton.get_bone_count() != 23:
		_fail("actual user-owned 23-joint GLB not imported")
		return
	if not bool(rig.rig_report.get("valid", false)) or rig.bones.size() < 20:
		_fail("complete humanoid role mapping failed")
		return
	var face: NusaFaceController = rig.face_controller
	if face == null or face.available_shapes().size() != 78:
		_fail("78 original morph targets not exposed to face controller")
		return
	if not rig.set_expression("blink", 0.02):
		_fail("blink expression missing")
		return
	for _frame in range(6):
		await process_frame
	var left: MeshInstance3D = face.shapes["eyeBlinkLeft"][0]["mesh"]
	var left_index: int = face.shapes["eyeBlinkLeft"][0]["index"]
	var right: MeshInstance3D = face.shapes["eyeBlinkRight"][0]["mesh"]
	var right_index: int = face.shapes["eyeBlinkRight"][0]["index"]
	if left.get_blend_shape_value(left_index) < 0.7 or right.get_blend_shape_value(right_index) < 0.7:
		_fail("face presets did not drive actual left and right eye morphs")
		return
	if not rig.set_expression("neutral", 0.02):
		_fail("neutral expression missing")
		return
	for _frame in range(6):
		await process_frame
	if left.get_blend_shape_value(left_index) > 0.3:
		_fail("neutral did not restore face morphs")
		return
	var part := Node3D.new()
	part.name = "TestItem"
	var packed := PackedScene.new()
	if packed.pack(part) != OK:
		_fail("could not create module fixture")
		return
	part.free()
	if not rig.attach_module("hand_right", packed):
		_fail("hand attachment rejected")
		return
	if str((rig.attachment_nodes["hand_right"] as BoneAttachment3D).bone_name) != "RightHand":
		_fail("attachment did not use mapped right hand")
		return
	if rig.attach_module("nonexistent_socket", packed):
		_fail("unsupported attachment slot unexpectedly accepted")
		return
	var animal_report: Dictionary = NusaRigProfile.inspect(rig.skeleton, animal)
	if not bool(animal_report["valid"]) or not animal_report["missing_optional"].has("Tail"):
		_fail("biped reuse should permit missing optional tail")
		return
	var spirit_report: Dictionary = NusaRigProfile.inspect(rig.skeleton, winged)
	if bool(spirit_report["valid"]) or not spirit_report["missing_required"].has("Wing_L"):
		_fail("winged rig should reject absent wing bones")
		return
	var four_leg_report: Dictionary = NusaRigProfile.inspect(rig.skeleton, quadruped)
	if bool(four_leg_report["valid"]) or not four_leg_report["missing_required"].has("FrontLeg_L"):
		_fail("biped rig must not silently masquerade as a quadruped")
		return
	print("PASS — Nusa kit: 23 bones, inherited profiles, 78 morphs, blink, sockets, incompatible rig rejected")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
