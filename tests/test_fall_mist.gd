extends SceneTree
## Sprint 28: translucent cliff-edge veils are bounded and render-only.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WaterBuilder.build_world(IslandDefinition.fixture_river())
	var mist: MeshInstance3D = world.get_node_or_null("FallMist")
	var falls: MeshInstance3D = world.get_node_or_null("Waterfalls")
	if mist == null or falls == null or mist.mesh.get_surface_count() == 0:
		_fail("waterfall lost the new side mist sheets")
		return
	if not mist.material_override is ShaderMaterial or not mist.material_override.shader.code.contains("TIME"):
		_fail("mist must be animated and alpha-blended")
		return
	var colors: PackedColorArray = mist.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if colors.size() < 24 or colors.size() > 30000:
		_fail("mist geometry count not appropriately bounded")
		return
	var maximum: float = 0.0
	var minimum: float = 1.0
	for color in colors:
		maximum = maxf(maximum, color.a)
		minimum = minf(minimum, color.a)
	if maximum < 0.13 or minimum > 0.021:
		_fail("mist side alpha should taper from transparent rock into waterfall")
		return
	if world.get_node_or_null("FallMist/CollisionShape3D") != null:
		_fail("decorative mist unexpectedly changes physics")
		return
	world.free()
	print("PASS — animated waterfall mist, shaded taper, bounded meshes, no extra collision")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
