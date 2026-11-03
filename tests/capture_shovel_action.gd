extends SceneTree
## Three original demo phases: ground shovel, walk+upper-body shovel, foot target debug.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	# Slow only the offline capture clock: preserves real gameplay durations.
	Engine.time_scale = 0.35
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	var actor: RiverCharacter = scene.physics_actor
	actor.mode = WaterRules.Mode.WALK
	scene.probe_mode = WaterRules.Mode.WALK
	actor.current_enabled = false
	actor.set_start(6.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(24):
		await physics_frame
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var tag := Label.new()
	tag.position = Vector2(22, 475)
	tag.add_theme_font_size_override("font_size", 21)
	tag.add_theme_color_override("font_color", Color(0.99, 0.99, 1.0))
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.12, 0.15))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	var overlay := CanvasLayer.new()
	overlay.add_child(tag)
	scene.add_child(overlay)
	for frame in range(36):
		if frame == 0:
			actor.try_use_shovel()
		if frame == 13:
			actor.set_input_direction(Vector2.RIGHT)
			actor.try_use_shovel()
		if frame == 25:
			actor.set_input_direction(Vector2.ZERO)
			actor.foot_probe.show_debug = true
		for _tick in range(8):
			await physics_frame
		for _tick in range(2):
			await process_frame
		var focus := Vector3(actor.global_position.x, actor.global_position.y + 0.68, actor.global_position.z)
		camera.size = 4.65
		camera.position = focus + Vector3(5.1, 6.4, 6.3)
		camera.look_at(focus)
		var phase: String = "A • SEKOP DI DARAT" if frame < 13 else ("B • SEKOP SAMBIL JALAN" if frame < 25 else "C • TARGET KAKI / IK LAB")
		tag.text = "%s  |  AKSI %s  |  BEKAS %s" % [phase, "ON" if actor.skeleton_bridge.shovel_active() else "OFF", actor.impact_effects.emitted_total]
		scene._update_status()
		await process_frame
		var snapshot: Image = viewport.get_texture().get_image()
		if snapshot == null or snapshot.is_empty():
			push_error("Shovel snapshot is unavailable")
			quit(2)
			return
		var path: String = ProjectSettings.globalize_path("res://shovel_frame_%02d.png" % frame)
		if snapshot.save_png(path) != OK:
			push_error("Could not save shovel frame")
			quit(3)
			return
		if frame == 4:
			snapshot.save_png(ProjectSettings.globalize_path("res://shovel_action_preview.png"))
		if frame == 7:
			snapshot.save_png(ProjectSettings.globalize_path("res://shovel_impact_preview.png"))
		if frame == 18:
			snapshot.save_png(ProjectSettings.globalize_path("res://shovel_walk_preview.png"))
		if frame == 29:
			snapshot.save_png(ProjectSettings.globalize_path("res://foot_targets_preview.png"))
	print("Capture saved: 36 shovel frames plus action/impact/walk/foot target previews")
	Engine.time_scale = 1.0
	quit(0)
