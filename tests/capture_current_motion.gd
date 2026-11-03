extends SceneTree
## Three phases: anchored swimmer, idle downstream drift, and upstream control.


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
	scene.enable_current = false
	viewport.add_child(scene)
	var actor: RiverCharacter = scene.physics_actor
	var unit: float = IslandDefinition.TILE_SIZE
	actor.mode = WaterRules.Mode.SWIM
	scene.probe_mode = WaterRules.Mode.SWIM
	actor.set_start(10.5 * unit, 6.5 * unit)
	actor.current_enabled = false
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var focus := Vector3(22.4, 0.2, 13.55)
	camera.size = 7.0
	camera.position = focus + Vector3(7.0, 8.0, 8.0)
	camera.look_at(focus)
	var start_flow: Vector2 = scene.water_rules.sample(actor.feet_position())["flow"]
	for frame in range(24):
		if frame == 4:
			scene.enable_current = true
			actor.current_enabled = true
		if frame == 16:
			actor.set_input_direction(-start_flow.normalized())
		for _wait in range(8):
			await physics_frame
		for _wait in range(2):
			await process_frame
		scene._update_status()
		var snap: Image = viewport.get_texture().get_image()
		if snap == null or snap.is_empty():
			push_error("Cannot capture current motion")
			quit(2)
			return
		var path: String = ProjectSettings.globalize_path("res://current_frame_%02d.png" % frame)
		if snap.save_png(path) != OK:
			push_error("Cannot save current animation frame")
			quit(3)
			return
		if frame == 12:
			snap.save_png(ProjectSettings.globalize_path("res://current_debug_preview.png"))
	print("Capture saved: 24 current + motion-state frames (960x540)")
	quit(0)
