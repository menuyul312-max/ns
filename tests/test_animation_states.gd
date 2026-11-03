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
	var unit: float = IslandDefinition.TILE_SIZE
	actor.set_start(12.5 * unit, 6.5 * unit)
	for _i in range(25):
		await physics_frame
	if actor.motion_state != RiverCharacter.MotionState.IDLE:
		_fail("initial idle state missing")
		return
	actor.set_input_direction(Vector2.LEFT)
	for _i in range(20):
		await physics_frame
	if actor.motion_state != RiverCharacter.MotionState.WALK or actor.walk_blend < 0.5:
		_fail("walk state/blend missing")
		return
	actor.set_input_direction(Vector2.ZERO)
	actor.set_start(24.86, 6.5 * unit)
	actor.mode = WaterRules.Mode.WADE
	for _i in range(22):
		await physics_frame
	if actor.motion_state != RiverCharacter.MotionState.WADE or actor.wade_blend < 0.6:
		_fail("shallow-water wade state/blend missing")
		return
	actor.set_start(10.5 * unit, 6.5 * unit)
	actor.mode = WaterRules.Mode.SWIM
	for _i in range(34):
		await physics_frame
	if actor.motion_state != RiverCharacter.MotionState.SWIM or actor.swim_blend < 0.8 or not actor.floating:
		_fail("swim state/blend missing")
		return
	if actor.arm_joints.size() != 2 or actor.leg_joints.size() != 2:
		_fail("procedural limb joints not created")
		return
	actor.set_start(12.5 * unit, 6.5 * unit)
	actor.mode = WaterRules.Mode.WALK
	for _i in range(40):
		await physics_frame
	if actor.motion_state != RiverCharacter.MotionState.IDLE or actor.swim_blend > 0.10 or actor.walk_blend > 0.10:
		_fail("state transition failed to decay to idle")
		return
	print("PASS — idle → walk → wade → swim → idle with continuous joint blend")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
