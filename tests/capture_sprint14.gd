extends SceneTree
## Genuine Godot screenshots of an authored route audit, not Nintendo imagery.


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
	scene.physics_actor.visible = false
	scene.use_physics_actor = false
	scene.traversal_probe.visible = false
	var camera: Camera3D = scene.reference_camera
	var canvas := CanvasLayer.new()
	var panel := Panel.new()
	panel.position = Vector2(25, 558)
	panel.size = Vector2(1230, 137)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.033, 0.10, 0.14, 0.88)
	bg.corner_radius_top_left = 12
	bg.corner_radius_top_right = 12
	bg.corner_radius_bottom_left = 12
	bg.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", bg)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(49, 582)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color(0.96, 0.99, 0.95))
	canvas.add_child(label)
	scene.add_child(canvas)
	var island := IslandDefinition.new(14, 10)
	for z in range(1, 9):
		for x in range(1, 13):
			island.set_height(x, z, 1)
	for z in range(1, 9):
		if z != 5:
			island.set_water(6, z, true)
	island.set_occupant(3, 7, 1)
	island.set_occupant(10, 3, 2)
	scene.composer.island = island
	scene.show_access_overlay = true
	scene._refresh_terrain()
	_focus(camera, island)
	for _i in range(18):
		await physics_frame
	var first: Dictionary = scene.access_audit
	if first["count"] != 2:
		push_error("Expected beach and joined plateau, got %s" % first["count"])
		quit(2)
		return
	label.text = "SPRINT 14 • SEBELUM | 1 wilayah dataran tinggi yang saling tersambung\nWarna menunjukkan komponen jalan kaki; pantai dihitung terpisah"
	await _shot(viewport, "access_regions_before.png")
	scene.composer.protect_connectivity = true
	var allowed: bool = scene.composer.toggle_water(6, 5)
	if allowed or scene.composer.last_edit_report.get("code") != "ACCESS_SPLIT":
		push_error("Expected access guard to reject bottleneck removal")
		quit(2)
		return
	scene._show_rejected_tile(6, 5)
	label.text = "PERLINDUNGAN ON | Edit tile merah DITOLAK: ACCESS_SPLIT\nMenambah air di jalur sempit memisahkan dua permukiman"
	await _shot(viewport, "access_edit_rejected.png")
	scene.composer.protect_connectivity = false
	if not scene.composer.toggle_water(6, 5):
		push_error("Permissive-mode comparison failed")
		quit(2)
		return
	scene._refresh_terrain()
	_focus(camera, island)
	if scene.access_audit["count"] != 3:
		push_error("Expected beach + two separate plateau regions")
		quit(2)
		return
	label.text = "SIMULASI TANPA PERLINDUNGAN | Dataran kiri dan kanan TERPISAH\nWarna yang berbeda mengungkap dua area yang kehilangan jalur jalan kaki"
	await _shot(viewport, "access_split_simulation.png")
	scene.composer.island = IslandDefinition.fixture_river()
	scene._refresh_terrain()
	_focus(camera, scene.island)
	label.text = "PULAU NUSANTARA | Peta akses pada terrain, sungai, dan tebing orisinal\nOverlay ini hanya memetakan jalan kaki dry-tile pada elevasi yang sama"
	await _shot(viewport, "access_island_overview.png")
	print("PASS CAPTURE — 4 images, graph audit, rejected bridge, permissive split and island")
	quit(0)


func _focus(camera: Camera3D, island: IslandDefinition) -> void:
	var look_at := Vector3(float(island.width) * IslandDefinition.TILE_SIZE * 0.50, 0.85, float(island.depth) * IslandDefinition.TILE_SIZE * 0.50)
	camera.size = 27.0
	camera.position = look_at + Vector3(19.0, 25.0, 20.0)
	camera.look_at(look_at)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(5):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty() or snapshot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Failed to capture " + file_name)
		quit(3)
