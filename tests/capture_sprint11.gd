extends SceneTree
## Reproducible focused captures. All geometry and the original chibi rig
## are rendered by Godot from this project (no generative reconstruction).

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	scene.get_node("EditorHelp").visible = false
	var actor: RiverCharacter = scene.physics_actor
	actor.current_enabled = false
	actor.set_start(5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	actor.mesh_root.rotation.y = PI
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var caption := Label.new()
	caption.position = Vector2(26, 480)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color(0.01, 0.05, 0.07))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	var overlay := CanvasLayer.new()
	overlay.add_child(caption)
	scene.add_child(overlay)
	for _i in range(36):
		await physics_frame
	var before_ankle: Vector3 = actor.foot_probe.foot_hits["right"]["world"]
	actor.foot_ik.set_ik_enabled(false)
	var patch := StaticBody3D.new()
	patch.name = "FootContactMicroterrain"
	patch.collision_layer = 8
	patch.collision_mask = 0
	patch.position = Vector3(before_ankle.x, 1.605, before_ankle.z)
	var shape := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(0.11, 0.11, 0.13)
	shape.shape = block
	patch.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = block.size
	visual.mesh = mesh
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.92, 0.59, 0.24)
	visual.material_override = soil
	patch.add_child(visual)
	scene.add_child(patch)
	for phase in range(2):
		actor.foot_ik.set_ik_enabled(phase == 1)
		for _i in range(19):
			await physics_frame
		for _i in range(2):
			await process_frame
		_camera_close(camera, actor)
		caption.text = "SPRINT 11 | %s | BENDA TANAH +11 cm" % ("SEBELUM IK" if phase == 0 else "SESUDAH IK")
		await process_frame
		var file_name: String = "ik_before_preview.png" if phase == 0 else "ik_after_preview.png"
		_save(viewport, file_name)
		print("CAPTURE ", file_name, " ankle=", actor.foot_probe.foot_hits["right"], " ik_active=", actor.foot_ik.active_sides)
	patch.queue_free()
	actor.foot_ik.set_ik_enabled(true)
	for _i in range(8):
		await physics_frame
	if not actor.try_use_shovel():
		push_error("Sprint 11 shovel capture could not start")
		quit(2)
		return
	for _i in range(19):
		await physics_frame
	for _i in range(2):
		await process_frame
	_camera_close(camera, actor)
	caption.text = "SPRINT 11 | GLB + SEKOP | ROTASI REST DIPERBAIKI"
	await process_frame
	_save(viewport, "shovel_grip_preview.png")
	var tip: MeshInstance3D = actor.shovel_prop.get_node("WorldAlignedGrip/PointedTip")
	print("CAPTURE shovel_grip_preview.png hand=", actor.shovel_prop.global_position, " tip=", tip.global_position, " visible=", actor.shovel_prop.visible, " bridge=", actor.skeleton_bridge.shovel_elapsed, " tool_rotation=", actor.shovel_prop.global_rotation)
	quit(0)


func _camera_close(camera: Camera3D, actor: RiverCharacter) -> void:
	var focal: Vector3 = actor.global_position + Vector3(0.0, -0.13, 0.0)
	camera.size = 2.9
	camera.position = focal + Vector3(2.2, 1.85, 2.3)
	camera.look_at(focal)


func _save(viewport: SubViewport, file_name: String) -> void:
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Failed to write screenshot " + file_name)
