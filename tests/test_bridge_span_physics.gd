extends SceneTree
## The full 3-tile bridge must work for the real CharacterBody3D capsule.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(10, 5)
	for z in range(5):
		for x in range(3, 6):
			island.set_water(x, z, true)
	var editor := IslandComposer.new(island)
	if not editor.cycle_connector(4, 2):
		_fail("three-tile span cannot be installed")
		return
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(TerrainBuilder.build_world(island))
	stage.add_child(IslandLinkBuilder.build_world(island))
	var walker := RiverCharacter.new()
	walker.configure(island, WaterRules.new(island))
	walker.mode = WaterRules.Mode.WALK
	walker.current_enabled = false
	stage.add_child(walker)
	walker.set_start(1.65 * IslandDefinition.TILE_SIZE, 2.5 * IslandDefinition.TILE_SIZE)
	var middle_deck_height: float = -100.0
	for _i in range(510):
		walker.set_input_direction(Vector2.RIGHT if walker.global_position.x < 7.2 * IslandDefinition.TILE_SIZE else Vector2.ZERO)
		await physics_frame
		var span_x: float = walker.global_position.x / IslandDefinition.TILE_SIZE
		if span_x > 4.25 and span_x < 4.75:
			middle_deck_height = maxf(middle_deck_height, walker.feet_position().y)
	if walker.global_position.x < 6.8 * IslandDefinition.TILE_SIZE or middle_deck_height < 0.10:
		_fail("capsule stopped or fell into water at long span: x=%.2f, middle feet=%.2f" % [walker.global_position.x, middle_deck_height])
		return
	print("PASS — capsule crossed real 3-water-cell collider and arched center %.2f" % middle_deck_height)
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
