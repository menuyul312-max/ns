extends SceneTree
## Illustrates the same destination rejected/accepted as water locomotion changes.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.show_zone_overlay = true
	viewport.add_child(scene)
	scene.traversal_probe.position = Vector3(12.5 * IslandDefinition.TILE_SIZE, 0.0, 6.5 * IslandDefinition.TILE_SIZE)
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var focus := Vector3(23.1, 0.1, 13.2)
	camera.size = 17.0
	camera.position = focus + Vector3(11.0, 13.0, 12.0)
	camera.look_at(focus)
	for frame in range(15):
		if frame == 5:
			scene.probe_mode = WaterRules.Mode.WADE
		if frame == 10:
			scene.probe_mode = WaterRules.Mode.SWIM
		var previous: Vector3 = scene.traversal_probe.position
		var next: Vector3 = previous + Vector3(-0.52, 0.0, 0.0)
		scene.probe_blocked = not scene.water_rules.can_traverse_path(previous, next, scene.probe_mode)
		if not scene.probe_blocked:
			scene.traversal_probe.position = next
			scene._snap_probe_height()
		scene._update_probe_appearance()
		scene._update_status()
		for _wait in range(2):
			await process_frame
		var frame_image: Image = viewport.get_texture().get_image()
		if frame_image == null or frame_image.is_empty():
			push_error("Cannot capture motion frame")
			quit(2)
			return
		var path: String = ProjectSettings.globalize_path("res://traversal_frame_%02d.png" % frame)
		if frame_image.save_png(path) != OK:
			push_error("Cannot save motion frame")
			quit(3)
			return
	print("Capture saved: 15 traversal frames")
	quit(0)
