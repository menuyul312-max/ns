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
	scene.probe_mode = WaterRules.Mode.SWIM
	scene.physics_actor.mode = WaterRules.Mode.SWIM
	scene.physics_actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	scene._update_status()
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var focus := Vector3(22.5, 0.2, 12.5)
	camera.size = 20.0
	camera.position = focus + Vector3(12.0, 14.0, 13.0)
	camera.look_at(focus)
	for _i in range(36):
		await physics_frame
	for _i in range(4):
		await process_frame
	var snapshot: Image = viewport.get_texture().get_image()
	if snapshot == null or snapshot.is_empty():
		push_error("Cannot capture traversal visual")
		quit(2)
		return
	var err: Error = snapshot.save_png(ProjectSettings.globalize_path("res://physics_swim_closeup.png"))
	if err != OK:
		push_error("Cannot save traversal visual: %s" % err)
		quit(3)
		return
	print("Capture saved: physics swim closeup (1280x720)")
	quit(0)
