extends SceneTree
## Stable viewpoints for coastal world-space deformation and river outlets.


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
	var camera: Camera3D = scene.reference_camera
	var canvas := CanvasLayer.new()
	var label := Label.new()
	var panel := Panel.new()
	panel.position = Vector2(24, 552)
	panel.size = Vector2(1232, 143)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.034, 0.10, 0.13, 0.9)
	bg.corner_radius_top_left = 11
	bg.corner_radius_top_right = 11
	bg.corner_radius_bottom_left = 11
	bg.corner_radius_bottom_right = 11
	panel.add_theme_stylebox_override("panel", bg)
	canvas.add_child(panel)
	label.position = Vector2(48, 579)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 0.96))
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
	if not scene.composer.cycle_connector(5, 5) or not scene.composer.cycle_connector(10, 5):
		push_error("Unable to create bridge/ramp capture fixture")
		quit(2)
		return
	scene.show_access_overlay = false
	scene._refresh_terrain()
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	scene.physics_actor.visible = false
	_focus(camera, Vector3(8.0 * IslandDefinition.TILE_SIZE, 0.0, 5.0 * IslandDefinition.TILE_SIZE), 21.6)
	label.text = "SPRINT 22 | Garis pesisir dibentuk dalam world-space, tidak lagi sempurna lurus\nGround dan collider menggunakan posisi vertex yang sama"
	await _shot(viewport, "s22_island_organic_coast.png")
	_focus(camera, Vector3(0.35 * IslandDefinition.TILE_SIZE, 0.0, 5.0 * IslandDefinition.TILE_SIZE), 10.7)
	label.text = "DETAIL PANTAI | Lekukan lembut memanjang melintasi batas tile\nWarp diberi seed pulau yang konsisten, bukan noise acak per sel"
	await _shot(viewport, "s22_coastline_closeup.png")
	_focus(camera, Vector3(5.4 * IslandDefinition.TILE_SIZE, 0.0, 0.80 * IslandDefinition.TILE_SIZE), 10.7)
	label.text = "MUARA | Kontur pantai diperlambat pada bukaan sungai ke laut\nAliran sungai tetap terhubung, meskipun ocean gameplay belum diterapkan"
	await _shot(viewport, "s22_river_mouth.png")
	print("PASS CAPTURE — S22 organic perimeter and freshwater sea outlet")
	quit(0)


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18, 24, 18)
	camera.look_at(center)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(6):
		await process_frame
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(3)
