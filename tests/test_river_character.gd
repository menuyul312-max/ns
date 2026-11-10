extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	var terrain := TerrainBuilder.build_world(island)
	root.add_child(terrain)
	var hydrology := WaterBuilder.build_world(island)
	root.add_child(hydrology)
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	actor.current_enabled = false # isolate baseline locomotion from Sprint 07 drift
	root.add_child(actor)
	var unit: float = IslandDefinition.TILE_SIZE
	actor.set_start(12.5 * unit, 6.5 * unit)
	for _i in range(15):
		await physics_frame
	if absf(actor.position.y - RiverCharacter.FOOT_OFFSET) > 0.13:
		_fail("gravity did not settle actor on dry ground: " + str(actor.position.y))
		return
	actor.mode = WaterRules.Mode.WALK
	actor.set_input_direction(Vector2.LEFT)
	for _i in range(100):
		await physics_frame
	var after_walk: Vector3 = actor.position
	if not actor.blocked or after_walk.x > 12.3 * unit:
		_fail("walk mode did not reach and stop at bank: " + str(after_walk))
		return
	actor.mode = WaterRules.Mode.WADE
	for _i in range(90):
		await physics_frame
	var after_wade: Vector3 = actor.position
	if after_wade.x >= after_walk.x - 0.08 or actor.water_depth <= 0.0 or actor.water_depth > WaterRules.DEEP_DEPTH or not actor.blocked:
		_fail("wade did not enter shallow water and stop before channel: " + str(after_wade) + " depth " + str(actor.water_depth))
		return
	actor.mode = WaterRules.Mode.SWIM
	for _i in range(115):
		await physics_frame
	actor.set_input_direction(Vector2.ZERO)
	for _i in range(25):
		await physics_frame
	var after_swim: Vector3 = actor.position
	# Horizontal stepping stops a fraction of a centimetre either side of the
	# continuous deep-depth isoline. Floating and substantial channel movement
	# are the physical behaviours under test; allow 1 cm contour tolerance.
	if after_swim.x >= after_wade.x - 0.6 or not actor.floating or actor.water_depth < WaterRules.DEEP_DEPTH - 0.01:
		_fail("swim did not move into deep flow and float: " + str(after_swim) + " after wade " + str(after_wade) + " depth " + str(actor.water_depth) + " floating " + str(actor.floating) + " blocked " + str(actor.blocked))
		return
	var expected_surface: float = WaterBuilder.WATER_ABOVE_GROUND + RiverCharacter.FLOAT_OFFSET
	if absf(after_swim.y - expected_surface) > 0.20:
		_fail("floating center too far from waterline: " + str(after_swim.y))
		return
	print("PASS — CharacterBody3D gravity, walk bank stop, wade shallow, swim float; x=%.2f→%.2f→%.2f" % [after_walk.x, after_wade.x, after_swim.x])
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
