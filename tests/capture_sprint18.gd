extends SceneTree
## True Godot frames to compare shared bank meander and non-striped ripples.


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
	var panel := Panel.new()
	panel.position = Vector2(24, 552)
	panel.size = Vector2(1232, 143)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.034, 0.10, 0.13, 0.90)
	background.corner_radius_top_left = 11
	background.corner_radius_top_right = 11
	background.corner_radius_bottom_left = 11
	background.corner_radius_bottom_right = 11
	panel.add_theme_stylebox_override("panel", background)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(47, 579)
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
	for x in [2, 3, 7, 8, 9, 10, 11]:
		island.set_terrain_layer(x, 5, 0, 1, 1, 0)
	scene.composer.island = island
	if not scene.composer.cycle_connector(5, 5) or not scene.composer.cycle_connector(10, 5):
		push_error("Capture fixture did not accept bridge and ramp")
		quit(2)
		return
	scene.show_access_overlay = false
	scene._refresh_terrain()
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	scene.physics_actor.visible = false
	_focus(camera, Vector3(8.0 * IslandDefinition.TILE_SIZE, 0, 5.0 * IslandDefinition.TILE_SIZE), 21.5)
	label.text = "SPRINT 18 | Kontur sungai kini melengkung kontinu di seluruh dunia\nGelombang air memakai tekstur berlapis; aliran fisika tetap tidak berubah"
	await _shot(viewport, "s18_river_overview.png")
	_focus(camera, Vector3(5.5 * IslandDefinition.TILE_SIZE, 0, 5.4 * IslandDefinition.TILE_SIZE), 12.4)
	label.text = "DETAIL SUNGAI | Tepi kiri-kanan dibentuk oleh domain warp yang sama\nPola diagonal panjang dari UV flow interpolation dihilangkan"
	await _shot(viewport, "s18_water_closeup.png")
	_focus(camera, Vector3(5.35 * IslandDefinition.TILE_SIZE, 0, 7.0 * IslandDefinition.TILE_SIZE), 9.4)
	label.text = "FRAME A | Gelombang lokal dan pusaran kecil tanpa garis diagonal memanjang\nWarna air berasal dari noise halus yang konsisten terhadap koordinat dunia"
	await _shot(viewport, "s18_wave_frame_a.png")
	for _i in range(105):
		await physics_frame
	label.text = "FRAME B | Posisi kamera sama, permukaan berkembang seiring waktu\nMotion berasal dari shader, bukan pergantian bentuk tile sungai"
	await _shot(viewport, "s18_wave_frame_b.png")
	_focus(camera, Vector3(7.0 * IslandDefinition.TILE_SIZE, 0, 5.5 * IslandDefinition.TILE_SIZE), 8.7)
	label.text = "SAMBUNGAN | Bibir sungai global melengkung, apron jembatan tetap visual-only\nKarakter dan collider mengikuti data air/tanah yang konsisten"
	await _shot(viewport, "s18_bridge_bank_closeup.png")
	print("PASS CAPTURE — S18 meandering global banks and two animated water frames")
	quit(0)


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18, 24, 18)
	camera.look_at(center)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(5):
		await process_frame
	var current: Image = viewport.get_texture().get_image()
	if current == null or current.is_empty() or current.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(3)
