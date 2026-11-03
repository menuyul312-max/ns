extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	root.add_child(TerrainBuilder.build_world(island))
	root.add_child(WaterBuilder.build_world(island))
	var rules := WaterRules.new(island)
	var unit: float = IslandDefinition.TILE_SIZE
	var spawn := Vector3(10.5 * unit, 0.0, 6.5 * unit)
	var sample: Dictionary = rules.sample(spawn)
	var flow: Vector2 = sample["flow"]
	if flow.length() < 0.20 or sample["zone"] != WaterRules.Zone.DEEP:
		_fail("fixture test point must be deep with nonzero flow")
		return
	var actor := RiverCharacter.new()
	actor.configure(island, rules)
	actor.mode = WaterRules.Mode.SWIM
	root.add_child(actor)
	actor.set_start(spawn.x, spawn.z)
	actor.current_enabled = true
	for _i in range(60):
		await physics_frame
	var downstream: Vector2 = Vector2(actor.global_position.x - spawn.x, actor.global_position.z - spawn.z)
	var downstream_progress: float = downstream.dot(flow.normalized())
	if downstream_progress < 0.20 or actor.flow_velocity.length() < 0.30:
		_fail("idle swimmer did not drift downstream: " + str(downstream_progress))
		return
	actor.set_start(spawn.x, spawn.z)
	actor.current_enabled = false
	for _i in range(60):
		await physics_frame
	var still: Vector2 = Vector2(actor.global_position.x - spawn.x, actor.global_position.z - spawn.z)
	if still.length() > 0.15 or actor.flow_velocity.length() > 0.001:
		_fail("disabled flow still moved idle swimmer: " + str(still))
		return
	actor.set_start(spawn.x, spawn.z)
	actor.current_enabled = true
	actor.set_input_direction(-flow.normalized())
	for _i in range(50):
		await physics_frame
	var upstream: Vector2 = Vector2(actor.global_position.x - spawn.x, actor.global_position.z - spawn.z)
	var upstream_progress: float = upstream.dot(flow.normalized())
	if upstream_progress > -0.15:
		_fail("swim control could not overcome river drift: " + str(upstream_progress))
		return
	print("PASS — downstream drift %.2f, no-flow %.2f, upstream %.2f (project units)" % [downstream_progress, still.length(), upstream_progress])
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
