extends SceneTree
## Render only our independent Godot meshes and intentionally experimental rules.


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
	var look_at := Vector3(6.0 * IslandDefinition.TILE_SIZE, 1.15, 5.4 * IslandDefinition.TILE_SIZE)
	camera.size = 16.5
	camera.position = look_at + Vector3(14.5, 18.0, 19.0)
	camera.look_at(look_at)
	var canvas := CanvasLayer.new()
	var backdrop := Panel.new()
	backdrop.position = Vector2(25, 560)
	backdrop.size = Vector2(1230, 135)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.11, 0.13, 0.87)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	backdrop.add_theme_stylebox_override("panel", style)
	canvas.add_child(backdrop)
	var caption := Label.new()
	caption.position = Vector2(48, 583)
	caption.add_theme_font_size_override("font_size", 25)
	caption.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94))
	canvas.add_child(caption)
	scene.add_child(canvas)
	for _i in range(20):
		await physics_frame
	caption.text = "SPRINT 13 • SEBELUM | Denah awal; validasi edit opsional belum aktif\nTerrain, kanal air, dan jalur sintetis orisinal Nusantara"
	await _shot(viewport, "build_rules_before.png")
	scene.composer.island.set_occupant(6, 6, 1)
	scene.composer.island.set_occupant(3, 4, 2)
	scene._refresh_terrain()
	# Refresh reframes the default camera; restore identical framing for A/B.
	camera.size = 16.5
	camera.position = look_at + Vector3(14.5, 18.0, 19.0)
	camera.look_at(look_at)
	scene.composer.strict_build_rules = true
	var allowed: bool = scene.composer.modify_tile(7, 6, 1)
	if allowed or scene.composer.last_edit_report.get("code") != "TREE_NEAR_EDIT":
		push_error("Scenario screenshot expected TREE_NEAR_EDIT")
		quit(2)
		return
	scene._show_rejected_tile(7, 6)
	caption.text = "SESUDAH | Pohon + rumah panggung; validasi 3×3 ON\nTile merah: edit DITOLAK — TREE_NEAR_EDIT (aturan eksperimen Nusantara)"
	await _shot(viewport, "build_rules_after.png")
	camera.size = 25.0
	look_at = Vector3(7.0 * IslandDefinition.TILE_SIZE, 1.0, 5.0 * IslandDefinition.TILE_SIZE)
	camera.position = look_at + Vector3(18.5, 25.0, 18.5)
	camera.look_at(look_at)
	caption.text = "PULAU NUSANTARA | Terrain dua layer + air + pohon + bangunan\n3×3 adalah konteks pemeriksaan (satu tile diedit), bukan brush 9 tile"
	await _shot(viewport, "build_rules_overview.png")
	print("PASS CAPTURE — 3 Godot screenshots, original 3x3 build validator A/B")
	quit(0)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(4):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty() or snapshot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Could not save " + file_name)
		quit(3)
