extends SceneTree
## Integration: actual CharacterBody3D capsule follows authored collision decks.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge_map := IslandDefinition.new(8, 5)
	bridge_map.set_water(4, 2, true)
	bridge_map.set_connector(4, 2, 5)
	var bridge_stage := _spawn(bridge_map)
	var bridge_actor: RiverCharacter = bridge_stage.get_node("PhysicsCharacter")
	bridge_actor.set_start(2.45 * IslandDefinition.TILE_SIZE, 2.5 * IslandDefinition.TILE_SIZE)
	var bridge_max_feet: float = -999.0
	for _i in range(235):
		bridge_actor.set_input_direction(Vector2.RIGHT if bridge_actor.global_position.x < 6.2 * IslandDefinition.TILE_SIZE else Vector2.ZERO)
		await physics_frame
		if absf(bridge_actor.global_position.x / IslandDefinition.TILE_SIZE - 4.5) < 0.15:
			bridge_max_feet = maxf(bridge_max_feet, bridge_actor.feet_position().y)
	if bridge_actor.global_position.x < 5.8 * IslandDefinition.TILE_SIZE or bridge_max_feet < 0.08:
		var feet := bridge_actor.feet_position()
		var check: bool = bridge_actor.rules.can_traverse_path(feet, feet + Vector3(0.15, 0, 0), WaterRules.Mode.WALK)
		_fail("bridge actor could not cross on its deck: x=%.2f, feet=%.2f, blocked=%s, graph=%s, zone=%s" % [bridge_actor.global_position.x, bridge_max_feet, bridge_actor.blocked, check, bridge_actor.rules.sample(feet)["label"]])
		return
	bridge_stage.queue_free()
	for _i in range(4):
		await physics_frame
	var ramp_map := IslandDefinition.new(8, 5)
	for z in range(5):
		for x in range(4, 8):
			ramp_map.set_height(x, z, 1)
	ramp_map.set_connector(3, 2, 2)
	var ramp_stage := _spawn(ramp_map)
	var ramp_actor: RiverCharacter = ramp_stage.get_node("PhysicsCharacter")
	ramp_actor.set_start(1.9 * IslandDefinition.TILE_SIZE, 2.5 * IslandDefinition.TILE_SIZE)
	for _i in range(285):
		ramp_actor.set_input_direction(Vector2.RIGHT if ramp_actor.global_position.x < 5.6 * IslandDefinition.TILE_SIZE else Vector2.ZERO)
		await physics_frame
	var final_feet: Vector3 = ramp_actor.feet_position()
	if final_feet.x < 4.6 * IslandDefinition.TILE_SIZE or final_feet.y < 1.20:
		_fail("ramp actor failed to reach elevated terrain: feet=%s" % [final_feet])
		return
	print("PASS — actual 3D capsule crossed bridge (deck %.2f) and ramp (feet %s)" % [bridge_max_feet, final_feet])
	quit(0)


func _spawn(island: IslandDefinition) -> Node3D:
	var stage := Node3D.new()
	stage.name = "PhysicalLinkLab"
	root.add_child(stage)
	stage.add_child(TerrainBuilder.build_world(island))
	stage.add_child(IslandLinkBuilder.build_world(island))
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	actor.mode = WaterRules.Mode.WALK
	actor.current_enabled = false
	stage.add_child(actor)
	return stage


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
