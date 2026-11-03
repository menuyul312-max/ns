extends SceneTree
## A stable close-up camera for reviewing the river-to-fall transition.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(scene)
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var s: float = IslandDefinition.TILE_SIZE
	var target := Vector3(8.95 * s, 0.70, 3.55 * s)
	camera.size = 12.3
	camera.position = target + Vector3(12.0, 12.0, 11.0)
	camera.look_at(target, Vector3.UP)
	for _i in range(12):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty():
		push_error("No frame from waterfall close-up camera")
		quit(2)
		return
	var path: String = ProjectSettings.globalize_path("res://waterfall_closeup.png")
	if snapshot.save_png(path) != OK:
		push_error("Could not save waterfall close-up")
		quit(3)
		return
	print("Capture saved: waterfall close-up (1280x720)")
	quit(0)
