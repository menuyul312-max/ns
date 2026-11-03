extends SceneTree
## Regression: C0 seam matching and surf field from shared shore geometry.
## Real Godot engine required; not covered by Python offline tests.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tile: float = IslandDefinition.TILE_SIZE
	var phase: float = 0.71
	var at_joint: float = tile * 3.0
	var prev: float = CoastContour._coherent_seam_wave(1.0, at_joint, phase, true, true)
	var next: float = CoastContour._coherent_seam_wave(0.0, at_joint, phase, true, true)
	if absf(prev - next) > 0.00001:
		_fail("wave discontinuity at coherent tile-to-tile boundary")
		return
	if absf(CoastContour._coherent_seam_wave(0.0, at_joint, phase, false, false)) > 0.00001:
		_fail("isolated shore corner moved across its supporting tile")
		return
	var island := IslandDefinition.new(8, 8)
	for z in range(2, 6):
		island.set_land(4, z, false)
	var x: float = tile * 4.0
	var z_joint: float = tile * 3.0
	var a: Vector3 = CoastContour._mask_seam_offset(island, Vector3(x, 0.0, z_joint - 0.0001), 1.0)
	var b: Vector3 = CoastContour._mask_seam_offset(island, Vector3(x, 0.0, z_joint + 0.0001), 1.0)
	if a.distance_to(b) > 0.002:
		_fail("bank displacement visible seam between two straight tile edges")
		return
	var sea_x: float = x + 0.34
	var sea_z: float = tile * 3.5
	var texture: ImageTexture = CoastBuilder.make_signed_coast_texture(island)
	var image: Image = texture.get_image()
	var width_world: float = float(island.width) * tile + 2.0 * CoastBuilder.SEA_MARGIN
	var depth_world: float = float(island.depth) * tile + 2.0 * CoastBuilder.SEA_MARGIN
	var ix: int = roundi((sea_x + CoastBuilder.SEA_MARGIN) / width_world * float(CoastBuilder.MASK_SDF_SAMPLES - 1))
	var iz: int = roundi((sea_z + CoastBuilder.SEA_MARGIN) / depth_world * float(CoastBuilder.MASK_SDF_SAMPLES - 1))
	var sample_world_x: float = -CoastBuilder.SEA_MARGIN + float(ix) * width_world / float(CoastBuilder.MASK_SDF_SAMPLES - 1)
	var sample_world_z: float = -CoastBuilder.SEA_MARGIN + float(iz) * depth_world / float(CoastBuilder.MASK_SDF_SAMPLES - 1)
	var sampled: float = image.get_pixel(ix, iz).r
	var expected: float = CoastContour.distance_to_coast(island, sample_world_x, sample_world_z)
	if sampled < 0.0 or absf(sampled - expected) > 0.12:
		_fail("surf SDF no longer tracks the actual shoreline: %f vs %f" % [sampled, expected])
		return
	print("PASS — coherent seam, isolated corner guard, shared geometric surf field")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
