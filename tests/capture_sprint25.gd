extends SceneTree
## Same fixed camera/light for editable inlet comparison and river/waterfall QA.


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
	var label := Label.new()
	label.position = Vector2(35, 587)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.98))
	var panel := Panel.new()
	panel.position = Vector2(18, 558)
	panel.size = Vector2(1244, 144)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.10, 0.14, 0.90)
	bg.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", bg)
	var canvas := CanvasLayer.new()
	canvas.add_child(panel)
	canvas.add_child(label)
	scene.add_child(canvas)
	var island := IslandDefinition.new(16, 10)
	for z in range(10):
		for x in range(4, 7):
			island.set_water(x, z, true)
	for z in range(2, 8):
		for x in range(11, 15):
			island.set_height(x, z, 1)
	island.set_occupant(2, 7, 1)
	island.set_occupant(13, 4, 2)
	scene.composer.island = island
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	_focus(camera, Vector3(8.0 * IslandDefinition.TILE_SIZE, 0.0, 5.0 * IslandDefinition.TILE_SIZE), 24.0)
	label.text = "SPRINT 22  /  BEFORE   •   Garis pantai semula\nBentuk pesisir hanya noise halus; belum bisa ditata dari denah"
	await _shot(viewport, "s25_coast_before.png")
	for index in range(2, 9):
		island.set_coast_inset(0, index, 0.92 * sin(float(index - 1) / 8.0 * PI))
	for index in range(9, 15):
		island.set_coast_inset(2, index, 1.08 * sin(float(index - 8) / 8.0 * PI))
	for index in range(4, 8):
		island.set_coast_inset(1, index, 0.54 * sin(float(index - 3) / 6.0 * PI))
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	_focus(camera, Vector3(8.0 * IslandDefinition.TILE_SIZE, 0.0, 5.0 * IslandDefinition.TILE_SIZE), 24.0)
	label.text = "SPRINT 23–24  /  AFTER   •   Pesisir dapat dibentuk per node\nGeometri, tabrakan aktor, dan jarak buih laut berbagi kontur"
	await _shot(viewport, "s25_coast_after.png")
	_focus(camera, Vector3(0.55 * IslandDefinition.TILE_SIZE, 0.0, 4.9 * IslandDefinition.TILE_SIZE), 10.7)
	label.text = "SPRINT 24  /  INLET CLOSEUP   •   Bibir pantai yang diedit\nOmbak menghitung signed distance ke garis pesisir sesungguhnya"
	await _shot(viewport, "s25_shore_editor_closeup.png")
	_focus(camera, Vector3(5.35 * IslandDefinition.TILE_SIZE, 0.0, 0.90 * IslandDefinition.TILE_SIZE), 11.1)
	label.text = "SPRINT 23  /  RIVER MOUTH   •   Air tawar melebur ke laut\nProfil garis pesisir dan peredaman warp menjaga jalan keluar sungai"
	await _shot(viewport, "s25_river_mouth.png")
	scene.composer.island = IslandDefinition.fixture_river()
	scene._refresh_terrain()
	scene.physics_actor.visible = false
	_focus(camera, Vector3(8.4 * IslandDefinition.TILE_SIZE, 0.65, 3.8 * IslandDefinition.TILE_SIZE), 12.2)
	label.text = "SPRINT 25  /  WATERFALL   •   Crest shoulder dan busa pecah\nRivulet bertingkat, zona plunge tidak lagi pita persegi berulang"
	await _shot(viewport, "s25_waterfall_detail.png")
	print("PASS CAPTURE — S23–25 profile sculpt, coastline waves, mouth, waterfall")
	quit(0)


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18.0, 24.0, 18.0)
	camera.look_at(center)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(7):
		await process_frame
	var shot: Image = viewport.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(2)
