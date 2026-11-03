extends SceneTree
## True capture from the actual Godot renderer. Run only with Godot 4.7+
## and a display-capable renderer (or configured virtual display); no fake PNG.


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
	var camera: Camera3D = scene.reference_camera
	var island := IslandDefinition.fixture_coast_mask()
	scene.composer.island = island
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	var panel := Panel.new()
	panel.position = Vector2(20, 703)
	panel.size = Vector2(1360, 117)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.14, 0.92)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.position = Vector2(38, 727)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.98))
	var hud := CanvasLayer.new()
	hud.add_child(panel)
	hud.add_child(label)
	scene.add_child(hud)
	_focus(camera, Vector3(10.0 * IslandDefinition.TILE_SIZE, 0.8, 7.0 * IslandDefinition.TILE_SIZE), 31.0)
	label.text = "SPRINT 46  /  GODOT RENDER  •  Pulau Nusantara aktual\nPantai melengkung, arus, buih, tebing, dan sungai: verifikasi visual"
	await _shot(viewport, "s46_godot_island_overview.png")
	_focus(camera, Vector3(14.5 * IslandDefinition.TILE_SIZE, 0.20, 7.0 * IslandDefinition.TILE_SIZE), 13.5)
	label.text = "SPRINT 46  /  GODOT RENDER  •  Teluk pesisir timur\nPeriksa gabungan mesh darat, skirt, collision, gradasi pasir, dan ombak"
	await _shot(viewport, "s46_godot_eastern_cove.png")
	_focus(camera, Vector3(8.7 * IslandDefinition.TILE_SIZE, 0.05, 10.35 * IslandDefinition.TILE_SIZE), 13.0)
	label.text = "SPRINT 46  /  GODOT RENDER  •  Muara selatan\nPeriksa kesinambungan bentuk bank sungai dan bibir laut"
	await _shot(viewport, "s46_godot_southern_outlet.png")
	var debug := _make_loop_debug(island)
	scene.add_child(debug)
	_focus(camera, Vector3(10.0 * IslandDefinition.TILE_SIZE, 0.7, 7.0 * IslandDefinition.TILE_SIZE), 31.0)
	label.text = "SPRINT 46  /  TOPOLOGY AUDIT  •  Cincin pantai mentah\nGaris merah = kontur mask untuk audit, BUKAN garis mesh yang sudah di-warp"
	await _shot(viewport, "s46_godot_contour_debug.png")
	print("PASS CAPTURE — four real Godot images saved in project root")
	quit(0)


func _make_loop_debug(island: IslandDefinition) -> MeshInstance3D:
	var rings: Dictionary = IslandCoastLoops.trace(island)
	var mesh := ImmediateMesh.new()
	for ring in rings["rings"]:
		var points: PackedVector2Array = ring["points"]
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in points:
			mesh.surface_add_vertex(Vector3(point.x, 0.38, point.y))
		if not points.is_empty():
			mesh.surface_add_vertex(Vector3(points[0].x, 0.38, points[0].y))
		mesh.surface_end()
	var item := MeshInstance3D.new()
	item.name = "TopologyOnly_DebugRings"
	item.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.23, 0.16)
	mat.no_depth_test = true
	item.material_override = mat
	return item


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18.0, 24.0, 18.0)
	camera.look_at(center)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _frame in range(9):
		await process_frame
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(2)
