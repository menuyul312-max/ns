extends SceneTree
## Rendered in Godot. All bridge/ramp geometry is original Nusantara code.


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
	var panel := Panel.new()
	panel.position = Vector2(24, 548)
	panel.size = Vector2(1232, 147)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.105, 0.116, 0.88)
	bg.corner_radius_top_left = 12
	bg.corner_radius_top_right = 12
	bg.corner_radius_bottom_left = 12
	bg.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", bg)
	var canvas := CanvasLayer.new()
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(46, 577)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.96, 0.99, 0.95))
	canvas.add_child(label)
	scene.add_child(canvas)
	var island := IslandDefinition.new(14, 10)
	for z in range(2, 8):
		for x in range(8, 13):
			island.set_height(x, z, 1)
	for z in range(10):
		island.set_water(4, z, true)
	island.set_occupant(2, 7, 1)
	island.set_occupant(10, 4, 2)
	for x in [2, 3, 5, 6, 7, 8, 9]:
		island.set_terrain_layer(x, 5, 0, 1, 1, 0)
	scene.composer.island = island
	scene.show_access_overlay = false
	# Deliberately obstruct the bank to show rejection from the real build rules.
	island.set_occupant(3, 5, 1)
	if scene.composer.cycle_connector(4, 5) or scene.composer.last_edit_report["code"] != "BANK_BLOCKED":
		push_error("Expected bridge-bank obstruction is not enforced")
		quit(2)
		return
	scene._refresh_terrain()
	_focus(camera, island, 20.0)
	label.text = "SPRINT 16 | Pemasangan jembatan ditolak: titik mendarat terhalang pohon\nValidasi kini melindungi jalur masuk dan keluar sebelum konstruksi dimulai"
	await _shot(viewport, "s16_validation_rejected.png")
	island.set_occupant(3, 5, 0)
	if not scene.composer.cycle_connector(4, 5) or not scene.composer.cycle_connector(7, 5):
		push_error("Connector fixture could not be built")
		quit(3)
		return
	scene._refresh_terrain()
	_focus(camera, island, 22.0)
	label.text = "SPRINT 16 | Sambungan jembatan bambu dan ramp kayu setelah dirapikan\nBilah dan tiang visual; lintasan tetap memakai satu collider dek kontinu"
	await _shot(viewport, "s16_island_after.png")
	scene.physics_actor.set_start(3.0 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(78):
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	var bridge_focus := Vector3(4.5 * IslandDefinition.TILE_SIZE, 0.15, 5.4 * IslandDefinition.TILE_SIZE)
	_camera_close(camera, bridge_focus, 8.8)
	label.text = "DETAIL JEMBATAN | 12 bilah kayu, balok tepi dan tiang bambu di air\nKarakter berdiri di atas satu bidang collider fisika yang mulus"
	await _shot(viewport, "s16_bridge_detail.png")
	for _i in range(172):
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	var ramp_focus := Vector3(8.15 * IslandDefinition.TILE_SIZE, 0.9, 5.35 * IslandDefinition.TILE_SIZE)
	_camera_close(camera, ramp_focus, 9.5)
	label.text = "DETAIL RAMP | Papan miring mengikuti elevasi 0 → 1 tanpa anak tangga collider\nTebing hanya dibuka pada lebar ramp; sisi lainnya tetap memiliki dinding"
	await _shot(viewport, "s16_ramp_detail.png")
	print("PASS CAPTURE — S16 validation, overview, bridge detail, ramp detail")
	quit(0)


func _focus(camera: Camera3D, island: IslandDefinition, size: float) -> void:
	var focus := Vector3(float(island.width) * IslandDefinition.TILE_SIZE * 0.5, 1.0, float(island.depth) * IslandDefinition.TILE_SIZE * 0.5)
	_camera_close(camera, focus, size)


func _camera_close(camera: Camera3D, focus: Vector3, size: float) -> void:
	camera.size = size
	camera.position = focus + Vector3(16.0, 22.0, 16.0)
	camera.look_at(focus)


func _shot(viewport: SubViewport, name: String) -> void:
	for _i in range(5):
		await process_frame
	var picture: Image = viewport.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(ProjectSettings.globalize_path("res://" + name)) != OK:
		push_error("Capture failed: " + name)
		quit(4)
