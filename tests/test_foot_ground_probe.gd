extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	root.add_child(TerrainBuilder.build_world(island))
	root.add_child(WaterBuilder.build_world(island))
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	root.add_child(actor)
	actor.set_start(5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(27):
		await physics_frame
	var probe: FootGroundProbe = actor.foot_probe
	if probe == null or probe.sampled_count < 1:
		_fail("foot-contact raycaster was not updated")
		return
	if probe.bone_indices.size() != 2:
		_fail("left/right foot bones were not recognized")
		return
	for side in ["left", "right"]:
		var sample: Dictionary = probe.foot_hits[side]
		if not bool(sample["valid"]):
			_fail("ground under " + side + " foot was not detected")
			return
		if not is_finite(float(sample["gap"])) or absf(float(sample["gap"])) > 0.20:
			_fail("unreasonable terrain-to-ankle gap on " + side + ": " + str(sample["gap"]) + ", foot=" + str(sample["world"]) + ", floor=" + str(sample["ground"]))
			return
	probe.show_debug = true
	for _i in range(3):
		await physics_frame
	if not (probe.markers["left"] as MeshInstance3D).visible or not (probe.markers["right"] as MeshInstance3D).visible:
		_fail("debug markers do not show independently on solid ground")
		return
	actor.mode = WaterRules.Mode.SWIM
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	for _i in range(33):
		await physics_frame
	if not actor.floating:
		_fail("actor did not enter swimming condition")
		return
	if (probe.markers["left"] as MeshInstance3D).visible or (probe.markers["right"] as MeshInstance3D).visible:
		_fail("foot ground-contact debug remained visible while swimming")
		return
	print("PASS — both imported foot bones raycast terrain; debug targets disappear in swim")
	quit(0)


func _fail(reason: String) -> void:
	push_error("FAIL — " + reason)
	quit(1)
