extends SceneTree
## Three real Godot render states of the user-owned GLB, if a 3D renderer is
## available. Does not use images or meshes from Nintendo's game.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Nusa screenshots require a display renderer (X11/Wayland); headless has no 3D frame buffer")
		quit(4)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 680)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.82, 0.88, 0.90)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	light.light_energy = 1.25
	stage.add_child(light)
	var ground := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(7.0, 5.0)
	ground.mesh = floor_mesh
	ground.position.y = -0.045
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.79, 0.76, 0.69)
	ground.material_override = floor_material
	stage.add_child(ground)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.0, 1.18, -3.6)
	camera.look_at(Vector3(0.0, 0.62, 0.0))
	camera.fov = 35.0
	camera.current = true
	var actor := Node3D.new()
	actor.position.y = 0.62
	stage.add_child(actor)
	var rig := CharacterRigVisual.new()
	actor.add_child(rig)
	rig.setup()
	if not rig.imported_glb:
		push_error("Nusa capture needs the original user-owned character GLB")
		quit(1)
		return
	var animator := SkeletonAnimationBridge.new()
	actor.add_child(animator)
	animator.setup(actor, rig)
	var out_dir: String = OS.get_environment("NUSA_CAPTURE_DIR")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for scene_name in ["neutral", "happy", "wave"]:
		rig.set_expression("happy" if scene_name != "neutral" else "neutral", 0.04)
		if scene_name == "wave":
			animator.fire_action("wave")
		for _i in range(20):
			await process_frame
		var texture: ViewportTexture = viewport.get_texture()
		if texture == null:
			push_error("Godot viewport texture unavailable")
			quit(2)
			return
		var shot: Image = texture.get_image()
		if shot == null or shot.is_empty():
			push_error("Godot did not provide a renderable viewport image")
			quit(2)
			return
		var filename: String = out_dir.path_join("nusa_kit_" + scene_name + ".png")
		var result: Error = shot.save_png(filename)
		if result != OK:
			push_error("Godot screenshot failed: " + filename)
			quit(3)
			return
		print("CAPTURE ", filename, " size=", shot.get_size())
	quit(0)
