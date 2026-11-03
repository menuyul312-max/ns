extends SceneTree
## All pixels are genuine Godot renders of original Nusantara assets.


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
	panel.position = Vector2(25, 556)
	panel.size = Vector2(1230, 139)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.038, 0.10, 0.13, 0.89)
	bg.corner_radius_top_left = 12
	bg.corner_radius_top_right = 12
	bg.corner_radius_bottom_left = 12
	bg.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", bg)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(48, 581)
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 0.94))
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
	scene.show_access_overlay = true
	scene._refresh_terrain()
	_focus(camera, island, 25.0)
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(18):
		await physics_frame
	label.text = "SPRINT 15 • SEBELUM | Sungai dan tebing memisahkan jalur berjalan\nPeta akses memberi warna berbeda pada wilayah yang belum terhubung"
	await _shot(viewport, "connectors_before.png")
	if not scene.composer.cycle_connector(4, 5) or not scene.composer.cycle_connector(7, 5):
		push_error("Could not prepare intended bridge/ramp capture")
		quit(2)
		return
	scene._refresh_terrain()
	_focus(camera, island, 25.0)
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	label.text = "SESUDAH | Jembatan bambu + ramp kayu menghubungkan wilayah\nDua connector fisik baru ikut dihitung sebagai sisi graf akses"
	await _shot(viewport, "connectors_after_access.png")
	scene.show_access_overlay = false
	scene._refresh_access_overlay()
	scene.physics_actor.set_start(3.0 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(70):
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	_focus(camera, island, 20.0)
	label.text = "JEMBATAN | Aktor melewati air di atas collider deck, bukan berenang\nJalur pusat jembatan mematikan efek basah dan terbaca sebagai daratan"
	await _shot(viewport, "connectors_bridge_walk.png")
	for _i in range(180):
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	var ramp_center := Vector3(8.2 * IslandDefinition.TILE_SIZE, 1.18, 5.3 * IslandDefinition.TILE_SIZE)
	camera.size = 11.3
	camera.position = ramp_center + Vector3(8.0, 10.0, 9.5)
	camera.look_at(ramp_center)
	label.text = "RAMP | CharacterBody3D naik dari elevasi 0 → 1 melalui bidang miring\nBibir tebing pada lokasi ramp dibuka agar kapsul tidak menabrak dinding"
	await _shot(viewport, "connectors_ramp_walk.png")
	print("PASS CAPTURE — 4 screenshots of bridge/ramp connectors and moving actor")
	quit(0)


func _focus(camera: Camera3D, island: IslandDefinition, orthographic_size: float) -> void:
	var look_at := Vector3(float(island.width) * IslandDefinition.TILE_SIZE * 0.5, 1.0, float(island.depth) * IslandDefinition.TILE_SIZE * 0.5)
	camera.size = orthographic_size
	camera.position = look_at + Vector3(18.0, 24.0, 18.0)
	camera.look_at(look_at)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(5):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty() or snapshot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(3)
