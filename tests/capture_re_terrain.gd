extends SceneTree
## Capture our own two-layer terrain implementation after reading RE evidence.
## Does NOT render or embed Nintendo terrain meshes, textures, or presets.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 608)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	var actor: RiverCharacter = scene.physics_actor
	actor.set_start(6.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var label := Label.new()
	label.position = Vector2(24, 549)
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.09, 0.10))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	scene.add_child(layer)
	scene.get_node("EditorHelp").visible = false
	for _i in range(24):
		await physics_frame
	_focus(camera, Vector3(6.5 * IslandDefinition.TILE_SIZE, 1.55, 6.1 * IslandDefinition.TILE_SIZE))
	label.text = "SEBELUM | DENAH DASAR + JALUR ORISINAL"
	await _shot(viewport, "terrain_re_before.png")
	for x in range(5, 8):
		scene.composer.island.set_terrain_layer(x, 6, 0, 1, (x + 1) % 4, (x + 2) % 4)
	for x in [5, 7]:
		scene.composer.island.set_terrain_layer(x, 6, 1, 3, 1, x % 4)
	scene._refresh_terrain()
	for _i in range(14):
		await physics_frame
	_focus(camera, Vector3(6.5 * IslandDefinition.TILE_SIZE, 1.55, 6.1 * IslandDefinition.TILE_SIZE))
	label.text = "SESUDAH | WARNA TANAH + DEKOR LAYER KEDUA"
	await _shot(viewport, "terrain_re_after.png")
	scene.get_node("EditorHelp").visible = true
	layer.visible = false
	camera.size = 30.0
	var center := Vector3(float(scene.island.width) * IslandDefinition.TILE_SIZE * 0.5, 1.15, float(scene.island.depth) * IslandDefinition.TILE_SIZE * 0.5)
	camera.position = center + Vector3(17.0, 23.0, 17.0)
	camera.look_at(center)
	await _shot(viewport, "terrain_re_overview.png")
	print("PASS CAPTURE — Sprint 12 RE-informed two-layer terrain A/B + overview")
	quit(0)


func _focus(camera: Camera3D, center: Vector3) -> void:
	camera.size = 8.1
	camera.position = center + Vector3(6.6, 8.7, 7.2)
	camera.look_at(center)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(3):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty() or snapshot.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed " + file_name)
		quit(2)
