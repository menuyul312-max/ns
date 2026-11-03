extends SceneTree
## Engine renderer captures two coast shader states; not a CPU diagram.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 840)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	scene.get_node("EditorHelp").visible = false
	scene.traversal_probe.visible = false
	scene.physics_actor.visible = false
	scene.composer.island = IslandDefinition.fixture_coast_mask()
	scene.show_region_diagnostic = false
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	var camera: Camera3D = scene.reference_camera
	var focus := Vector3(14.5 * IslandDefinition.TILE_SIZE, 0.3, 7.0 * IslandDefinition.TILE_SIZE)
	camera.size = 14.0
	camera.position = focus + Vector3(12.0, 16.0, 12.0)
	camera.look_at(focus)
	var caption := Label.new()
	caption.position = Vector2(28, 760)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color.WHITE)
	var layer := CanvasLayer.new()
	layer.add_child(caption)
	scene.add_child(layer)
	caption.text = "SPRINT 51 • REAL GODOT COAST CAPTURE • WAVE PHASE A"
	await _shot(viewport, "s51_godot_coast_phase_a.png")
	await create_timer(2.7).timeout
	caption.text = "SPRINT 51 • REAL GODOT COAST CAPTURE • WAVE PHASE B (+2.7s)"
	await _shot(viewport, "s51_godot_coast_phase_b.png")
	print("PASS CAPTURE — real Godot coast frames A/B")
	quit(0)


func _shot(viewport: SubViewport, filename: String) -> void:
	for _i in range(9):
		await process_frame
	var picture: Image = viewport.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(ProjectSettings.globalize_path("res://" + filename)) != OK:
		push_error("Failed Godot screenshot: " + filename)
		quit(2)
