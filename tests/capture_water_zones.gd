extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.show_zone_overlay = true
	viewport.add_child(scene)
	for _i in range(8):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty():
		push_error("Cannot capture zone visual")
		quit(2)
		return
	var path: String = ProjectSettings.globalize_path("res://water_zones_preview.png")
	var err: Error = snapshot.save_png(path)
	if err != OK:
		push_error("Cannot save zone visual: %s" % err)
		quit(3)
		return
	print("Capture saved: water zones (1280x720)")
	quit(0)
