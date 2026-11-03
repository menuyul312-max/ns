extends SceneTree
## Real Godot capture using matched viewpoints to audit topology and water.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	scene.get_node("EditorHelp").visible = false
	scene.traversal_probe.visible = false
	scene.physics_actor.visible = false
	var camera: Camera3D = scene.reference_camera
	var panel := Panel.new()
	panel.position = Vector2(20, 556)
	panel.size = Vector2(1240, 146)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.095, 0.13, 0.91)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.position = Vector2(45, 581)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 0.98))
	var ui := CanvasLayer.new()
	ui.add_child(panel)
	ui.add_child(label)
	scene.add_child(ui)
	var after: IslandDefinition = IslandDefinition.fixture_coast_mask()
	var before: IslandDefinition = IslandDefinition.from_dictionary(after.as_dictionary())
	for z in range(before.depth):
		for x in range(before.width):
			if not before.is_land(x, z):
				before.set_land(x, z, true)
	scene.composer.island = before
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	_focus(camera, Vector3(10.0 * IslandDefinition.TILE_SIZE, 0, 7.0 * IslandDefinition.TILE_SIZE), 30.0)
	label.text = "SPRINT 25  /  BEFORE TOPOLOGY   •   Semua tile masih daratan\nKontur luar hanya dibengkokkan; tidak ada teluk atau pulau terpisah"
	await _shot(viewport, "s28_coast_before.png")
	scene.composer.island = after
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	_focus(camera, Vector3(10.0 * IslandDefinition.TILE_SIZE, 0, 7.0 * IslandDefinition.TILE_SIZE), 30.0)
	label.text = "SPRINT 26–27  /  AFTER TOPOLOGY   •   Mask membentuk teluk dan gosong\nMesh/collider hilang pada sel laut, ombak mengikuti jarak tepian baru"
	await _shot(viewport, "s28_coast_after.png")
	_focus(camera, Vector3(14.5 * IslandDefinition.TILE_SIZE, 0, 7.0 * IslandDefinition.TILE_SIZE), 12.4)
	label.text = "SPRINT 27  /  EASTERN COVE   •   Pantai topologis, bukan tepi persegi\nBentuk bibir darat disesuaikan dan celah diisi laut procedural"
	await _shot(viewport, "s28_east_cove_closeup.png")
	_focus(camera, Vector3(7.5 * IslandDefinition.TILE_SIZE, 0.6, 5.55 * IslandDefinition.TILE_SIZE), 12.1)
	label.text = "SPRINT 28  /  FALLING WATER   •   River curtain + terrain mask\nCek sambungan tirai, tebing, dan buih di kaki air terjun"
	await _shot(viewport, "s28_waterfall_detail.png")
	_focus(camera, Vector3(7.8 * IslandDefinition.TILE_SIZE, 0, 10.15 * IslandDefinition.TILE_SIZE), 12.0)
	label.text = "SPRINT 27  /  RIVER OUTLET   •   Sungai dialirkan ke laut dari mask\nBank di sisi outlet disaring, alpha sungai menipis menuju pesisir"
	await _shot(viewport, "s28_river_mouth.png")
	print("PASS CAPTURE — Sprint 26–28 topology, inlet, waterfall, river mouth")
	quit(0)


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18, 24, 18)
	camera.look_at(center)


func _shot(viewport: SubViewport, path: String) -> void:
	for _i in range(7):
		await process_frame
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(ProjectSettings.globalize_path("res://" + path)) != OK:
		push_error("Capture failed: " + path)
		quit(2)
