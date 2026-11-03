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
	var bridge: MannequinAnimationBridge = actor.animation_bridge
	if bridge == null or not bridge.initialized or not bridge.animation_tree.active:
		_fail("AnimationTree not initialized")
		return
	for clip in MannequinAnimationBridge.CLIPS:
		if not bridge.animation_player.has_animation(clip):
			_fail("Missing AnimationPlayer clip: " + clip)
			return
	actor.set_start(12.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	for _i in range(14):
		await physics_frame
	if str(bridge.playback.get_current_node()) != "idle":
		_fail("AnimationTree did not begin in idle: " + str(bridge.playback.get_current_node()))
		return
	actor.set_input_direction(Vector2.LEFT)
	for _i in range(20):
		await physics_frame
	if bridge.current_clip != "walk" or str(bridge.playback.get_current_node()) != "walk":
		_fail("Tree did not transition into walk")
		return
	var arm_before: float = actor.arm_joints[0].rotation.x
	for _i in range(9):
		await physics_frame
	var arm_after: float = actor.arm_joints[0].rotation.x
	if absf(arm_before - arm_after) < 0.08:
		_fail("AnimationPlayer did not move arm rotation across loop: " + str(arm_before) + ", " + str(arm_after))
		return
	actor.set_input_direction(Vector2.ZERO)
	actor.set_start(10.5 * IslandDefinition.TILE_SIZE, 6.5 * IslandDefinition.TILE_SIZE)
	actor.mode = WaterRules.Mode.SWIM
	for _i in range(28):
		await physics_frame
	if bridge.current_clip != "swim" or str(bridge.playback.get_current_node()) != "swim":
		_fail("Tree did not reach swim")
		return
	print("PASS — AnimationTree clips, state travel, and actual limb keyframes play")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
