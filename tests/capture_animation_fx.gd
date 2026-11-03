extends SceneTree
## Original lab animation phases + water contact ring visuals.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.manual_actor_control = true
	scene.enable_current = false
	viewport.add_child(scene)
	var actor: RiverCharacter = scene.physics_actor
	actor.current_enabled = false
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var unit: float = IslandDefinition.TILE_SIZE
	var tag := Label.new()
	tag.position = Vector2(22, 468)
	tag.add_theme_font_size_override("font_size", 21)
	tag.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	tag.add_theme_color_override("font_shadow_color", Color(0.03, 0.12, 0.17))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	var layer := CanvasLayer.new()
	layer.add_child(tag)
	scene.add_child(layer)
	for frame in range(36):
		if frame == 0:
			actor.mode = WaterRules.Mode.WALK
			scene.probe_mode = WaterRules.Mode.WALK
			# Raised inland terrace has enough room for an uninterrupted walk.
			actor.set_start(5.5 * unit, 5.5 * unit)
			actor.set_input_direction(Vector2.RIGHT)
		if frame == 10:
			actor.mode = WaterRules.Mode.WADE
			scene.probe_mode = WaterRules.Mode.WADE
			actor.set_start(24.86, 6.5 * unit)
			actor.set_input_direction(Vector2.LEFT)
		if frame == 19:
			actor.mode = WaterRules.Mode.SWIM
			scene.probe_mode = WaterRules.Mode.SWIM
			actor.set_start(10.5 * unit, 6.5 * unit)
			# Travel slowly with the centerline to keep the swimmer in deep water.
			var channel_flow: Vector2 = scene.water_rules.sample(actor.feet_position())["flow"]
			actor.set_input_direction(channel_flow.normalized() * 0.32)
		if frame == 30:
			actor.set_input_direction(Vector2.ZERO)
		for _tick in range(6):
			await physics_frame
		for _tick in range(2):
			await process_frame
		# Follow the actual actor elevation so terrace footage stays centered.
		# Aim slightly above the actor to frame it below the top-left debug HUD.
		var focus := Vector3(actor.global_position.x, actor.global_position.y + 0.65, actor.global_position.z)
		camera.size = 5.15
		camera.position = focus + Vector3(5.7, 7.1, 6.9)
		camera.look_at(focus)
		var phase: String = "A • WALK / DARAT" if frame < 10 else ("B • WADE / TEPI" if frame < 19 else "C • SWIM / ALUR AIR")
		tag.text = "%s    |    %s    |    RIPPLE %s" % [phase, actor.animation_bridge.current_clip.to_upper(), actor.ripple_effects.emitted_total]
		scene._update_status()
		await process_frame
		var snap: Image = viewport.get_texture().get_image()
		if snap == null or snap.is_empty():
			push_error("Could not capture animation FX")
			quit(2)
			return
		var target: String = ProjectSettings.globalize_path("res://rig_frame_%02d.png" % frame)
		if snap.save_png(target) != OK:
			push_error("Cannot save animation FX frame")
			quit(3)
			return
		if frame == 5:
			snap.save_png(ProjectSettings.globalize_path("res://rig_walk_preview.png"))
		if frame == 16:
			snap.save_png(ProjectSettings.globalize_path("res://rig_wade_preview.png"))
		if frame == 25:
			snap.save_png(ProjectSettings.globalize_path("res://rig_swim_preview.png"))
		if frame == 30:
			snap.save_png(ProjectSettings.globalize_path("res://rig_swim_closeup.png"))
	print("Capture saved: 36 rig frames and walk/wade/swim GLB previews")
	quit(0)
