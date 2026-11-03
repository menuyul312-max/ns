extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var camera: Camera3D = scene.get_node("ReferenceCamera")
	var position: Vector3 = Vector3(7.5 * IslandDefinition.TILE_SIZE, IslandDefinition.HEIGHT_STEP, 2.5 * IslandDefinition.TILE_SIZE)
	var screen: Vector2 = camera.unproject_position(position)
	scene._edit_at_screen(screen, 1)
	if scene.composer.island.height_at(7, 2) != 2:
		push_error("FAIL — mouse ray did not raise the selected elevated tile")
		quit(1)
		return
	await physics_frame
	var surface_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position + Vector3(0, 10, 0), position + Vector3(0, -5, 0))
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(surface_query)
	if hit.is_empty() or not is_equal_approx(hit["position"].y, 2.0 * IslandDefinition.HEIGHT_STEP):
		push_error("FAIL — terrain collision did not rebuild after painting")
		quit(1)
		return
	var style_event := InputEventMouseButton.new()
	style_event.button_index = MOUSE_BUTTON_LEFT
	style_event.position = camera.unproject_position(Vector3(7.5 * IslandDefinition.TILE_SIZE, 2.0 * IslandDefinition.HEIGHT_STEP, 2.5 * IslandDefinition.TILE_SIZE))
	style_event.pressed = true
	style_event.alt_pressed = true
	scene._input(style_event)
	if int(scene.composer.island.terrain_layer_at(7, 2, 0)["unit"]) != 1:
		push_error("FAIL — Alt+click did not paint surface layer")
		quit(1)
		return
	style_event.alt_pressed = false
	style_event.ctrl_pressed = true
	scene._input(style_event)
	if int(scene.composer.island.terrain_layer_at(7, 2, 1)["unit"]) != 1:
		push_error("FAIL — Ctrl+click did not paint detail layer")
		quit(1)
		return
	var wet_cell: Vector3 = Vector3(6.5 * IslandDefinition.TILE_SIZE, IslandDefinition.HEIGHT_STEP - 0.29, 2.5 * IslandDefinition.TILE_SIZE)
	var wet_screen: Vector2 = camera.unproject_position(wet_cell)
	if not scene.composer.island.is_water(6, 2):
		push_error("FAIL — fixture expected a wet tile at (6,2)")
		quit(1)
		return
	var previous_water: PackedByteArray = scene.composer.island.water.duplicate()
	scene._edit_at_screen(wet_screen, 1, true)
	if scene.composer.island.is_water(6, 2):
		var modified: Array[String] = []
		for index in range(previous_water.size()):
			if previous_water[index] != scene.composer.island.water[index]:
				modified.append(str(Vector2i(index % scene.composer.island.width, index / scene.composer.island.width)))
		push_error("FAIL — screen-space water brush targeted %s instead of (6,2)" % [modified])
		quit(1)
		return
	if scene.water_root.get_node("WaterTriggers").get_child_count() != 19:
		push_error("FAIL — area triggers did not update after water edit")
		quit(1)
		return
	var prop_event := InputEventMouseButton.new()
	prop_event.button_index = MOUSE_BUTTON_RIGHT
	prop_event.pressed = true
	prop_event.shift_pressed = true
	prop_event.position = camera.unproject_position(Vector3(7.5 * IslandDefinition.TILE_SIZE, 2.0 * IslandDefinition.HEIGHT_STEP, 2.5 * IslandDefinition.TILE_SIZE))
	scene._input(prop_event)
	if scene.composer.island.occupant_at(7, 2) != 1 or scene.terrain_root.get_node("TileOccupants").get_child_count() != 1:
		push_error("FAIL — Shift+right-click did not place original tree prop")
		quit(1)
		return
	print("PASS — screen-space terrain/water and two-layer painting; Shift+right-click places prop")
	quit(0)
