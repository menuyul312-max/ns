extends SceneTree
## Captures physical capsule state transitions, not scripted marker teleports.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.show_zone_overlay = true
	scene.manual_actor_control = true
	viewport.add_child(scene)
	var unit: float = IslandDefinition.TILE_SIZE
	scene.physics_actor.set_start(12.5 * unit, 6.5 * unit)
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var focus := Vector3(23.1, 0.1, 13.2)
	camera.size = 17.0
	camera.position = focus + Vector3(11.0, 13.0, 12.0)
	camera.look_at(focus)
	var actor: RiverCharacter = scene.physics_actor
	for frame in range(19):
		if frame == 5:
			actor.mode = WaterRules.Mode.WADE
			scene.probe_mode = WaterRules.Mode.WADE
		if frame == 10:
			actor.mode = WaterRules.Mode.SWIM
			scene.probe_mode = WaterRules.Mode.SWIM
		actor.set_input_direction(Vector2.LEFT)
		for _wait in range(12):
			await physics_frame
		actor.set_input_direction(Vector2.ZERO)
		for _wait in range(2):
			await process_frame
		scene._update_status()
		var image_frame: Image = viewport.get_texture().get_image()
		if image_frame == null or image_frame.is_empty():
			push_error("Cannot capture physics frame")
			quit(2)
			return
		var path: String = ProjectSettings.globalize_path("res://physics_frame_%02d.png" % frame)
		if image_frame.save_png(path) != OK:
			push_error("Cannot save physics frame")
			quit(3)
			return
	print("Capture saved: 19 CharacterBody3D physics frames")
	quit(0)
