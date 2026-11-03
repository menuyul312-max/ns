extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	root.add_child(TerrainBuilder.build_world(island))
	root.add_child(WaterBuilder.build_world(island))
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	actor.current_enabled = false
	root.add_child(actor)
	if actor.ripple_effects == null:
		_fail("ripple emitter missing")
		return
	actor.set_start(12.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	for _i in range(12):
		await physics_frame
	if actor.ripple_effects.emitted_total != 0:
		_fail("dry land generated wet ripple")
		return
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	actor.mode = WaterRules.Mode.SWIM
	for _i in range(14):
		await physics_frame
	if actor.ripple_effects.emitted_total < 1 or actor.ripple_effects.active_ripples.is_empty():
		_fail("entering water did not generate ring")
		return
	var first: Dictionary = actor.ripple_effects.active_ripples[0]
	var first_node: MeshInstance3D = first["node"]
	if first_node.mesh == null or first_node.material_override == null:
		_fail("ring missing geometry/material")
		return
	var previous_emissions: int = actor.ripple_effects.emitted_total
	actor.set_input_direction(Vector2.LEFT)
	for _i in range(48):
		await physics_frame
	if actor.ripple_effects.emitted_total <= previous_emissions:
		_fail("moving swimmer did not create additional ripples")
		return
	actor.set_input_direction(Vector2.ZERO)
	actor.set_start(12.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	for _i in range(22):
		await physics_frame
	actor.ripple_effects._process(WaterRippleFX.LIFETIME + 0.01)
	if not actor.ripple_effects.active_ripples.is_empty():
		_fail("expired rings remain in scene")
		return
	print("PASS — dry/entry/moving ripple events and bounded lifetime")
	quit(0)


func _fail(reason: String) -> void:
	push_error("FAIL — " + reason)
	quit(1)
