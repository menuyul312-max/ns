extends SceneTree
## Godot screenshot lab: genuine renderer, authored 3-tile bridge + bank aprons.


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
	panel.position = Vector2(24, 551)
	panel.size = Vector2(1232, 143)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.035, 0.10, 0.13, 0.89)
	skin.corner_radius_top_left = 12
	skin.corner_radius_top_right = 12
	skin.corner_radius_bottom_left = 12
	skin.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", skin)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(46, 579)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.97, 0.98, 0.95))
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
	scene.show_access_overlay = false
	scene._refresh_terrain()
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	_focus(camera, Vector3(8 * IslandDefinition.TILE_SIZE, 0, 5 * IslandDefinition.TILE_SIZE), 21.5)
	label.text = "SPRINT 17 • SEBELUM | Tiga tile air memisahkan dua sisi pulau\nJembatan satu tile Sprint 16 belum dapat melintasi sungai selebar ini"
	await _shot(viewport, "s17_before_wide_river.png")
	if not scene.composer.cycle_connector(5, 5) or not scene.composer.cycle_connector(10, 5):
		push_error("Could not place intended long bridge and ramp")
		quit(2)
		return
	scene._refresh_terrain()
	scene.physics_actor.set_start(2.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	_focus(camera, Vector3(8 * IslandDefinition.TILE_SIZE, 0, 5 * IslandDefinition.TILE_SIZE), 21.5)
	label.text = "SESUDAH | Satu konstruksi jembatan bambu melewati tiga tile air sekaligus\nPapan, balok dan collider menyatu; ramp masih menghubungkan bukit di kanan"
	await _shot(viewport, "s17_after_wide_bridge.png")
	for _i in range(490):
		if scene.physics_actor.global_position.x >= 5.6 * IslandDefinition.TILE_SIZE:
			break
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	if scene.physics_actor.global_position.x < 5.4 * IslandDefinition.TILE_SIZE:
		push_error("Actor did not reach long-bridge middle in capture")
		quit(3)
		return
	_close(camera, Vector3(5.5 * IslandDefinition.TILE_SIZE, 0.08, 5.4 * IslandDefinition.TILE_SIZE), 12.8)
	label.text = "FISIKA | Kapsul 3D berjalan di atas satu dek jembatan yang melengkung\nTiga tile air memiliki satu collider tanpa celah di titik sambung"
	await _shot(viewport, "s17_actor_midspan.png")
	for _i in range(180):
		if scene.physics_actor.global_position.x >= 7.45 * IslandDefinition.TILE_SIZE:
			break
		scene.physics_actor.set_input_direction(Vector2.RIGHT)
		await physics_frame
	scene.physics_actor.set_input_direction(Vector2.ZERO)
	_close(camera, Vector3(7.0 * IslandDefinition.TILE_SIZE, 0.05, 5.5 * IslandDefinition.TILE_SIZE), 8.4)
	label.text = "DETAIL TEPIAN | Transisi pasir berbatas bergelombang + batu kecil\nLapisan visual menyamarkan sambungan dek ke tanah tanpa collider tambahan"
	await _shot(viewport, "s17_bank_apron_detail.png")
	print("PASS CAPTURE — S17 river before, long bridge, midspan actor, scalloped bank")
	quit(0)


func _focus(camera: Camera3D, center: Vector3, size: float) -> void:
	_close(camera, center, size)


func _close(camera: Camera3D, center: Vector3, size: float) -> void:
	camera.size = size
	camera.position = center + Vector3(18.0, 24.0, 18.0)
	camera.look_at(center)


func _shot(viewport: SubViewport, filename: String) -> void:
	for _i in range(5):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(ProjectSettings.globalize_path("res://" + filename)) != OK:
		push_error("Could not save screenshot " + filename)
		quit(4)
