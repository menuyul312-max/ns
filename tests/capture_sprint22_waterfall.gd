extends SceneTree
## Sprint 22: three-layer waterfall geometry photographed at equal framing.


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
	var size: float = IslandDefinition.TILE_SIZE
	var target := Vector3(8.9 * size, 0.72, 3.52 * size)
	var canvas := CanvasLayer.new()
	var panel := Panel.new()
	panel.position = Vector2(24, 552)
	panel.size = Vector2(1232, 143)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.034, 0.10, 0.13, 0.88)
	bg.corner_radius_top_left = 11
	bg.corner_radius_top_right = 11
	bg.corner_radius_bottom_left = 11
	bg.corner_radius_bottom_right = 11
	panel.add_theme_stylebox_override("panel", bg)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(48, 579)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.97, 0.99, 0.96))
	canvas.add_child(label)
	scene.add_child(canvas)
	camera.size = 10.5
	camera.position = target + Vector3(12.5, 12.0, 10.0)
	camera.look_at(target)
	label.text = "SPRINT 22 | Tiga lembar air berbagi bibir atas dan kaki bawah\nBagian tengah memiliki ketebalan geometri dan shading bergelombang"
	await _shot(viewport, "s22_waterfall_overview.png")
	camera.size = 7.7
	camera.position = target + Vector3(12.5, 9.0, 11.0)
	camera.look_at(target)
	label.text = "DETAIL AIR TERJUN | Lembaran transparan bertingkat dan busa dasar\nBukan hanya satu quad tipis; side-cliff dan mist masih perlu perbaikan"
	await _shot(viewport, "s22_waterfall_closeup.png")
	for _i in range(150):
		await physics_frame
	label.text = "AIR TERJUN +2.5s | Kamera tetap, tekstur air dan foam berkembang\nFaset tebing memakai koordinat dunia agar tidak menjadi blok per tile"
	await _shot(viewport, "s22_waterfall_later.png")
	print("PASS CAPTURE — S22 waterfall three-sheet review")
	quit(0)


func _shot(viewport: SubViewport, file_name: String) -> void:
	for _i in range(6):
		await process_frame
	var frame: Image = viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(ProjectSettings.globalize_path("res://" + file_name)) != OK:
		push_error("Capture failed: " + file_name)
		quit(3)
