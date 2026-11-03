extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var scene: PackedScene = load("res://scenes/main.tscn")
	viewport.add_child(scene.instantiate())
	for _i in range(8):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty():
		push_error("Rendering backend did not return a frame; headless image capture unavailable")
		quit(2)
		return
	var path: String = ProjectSettings.globalize_path("res://terrain_preview.png")
	var error: Error = snapshot.save_png(path)
	if error != OK:
		push_error("Cannot save preview image: %s" % error)
		quit(3)
		return
	print("Capture saved: ", path, " (", snapshot.get_width(), "x", snapshot.get_height(), ")")
	quit(0)
