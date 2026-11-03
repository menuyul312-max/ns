extends SceneTree
## Checks the independently authored tile representation inspired by the
## validated terrain record in the user's ACNH 1.0.0 RE report.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for level in range(6):
		if IslandDefinition.normalize_reference_height(level) != level:
			_fail("height %d was not preserved" % level)
			return
	for bad in [6, 7, 255]:
		if IslandDefinition.normalize_reference_height(bad) != 4:
			_fail("invalid reference height did not use fallback 4")
			return
	if IslandDefinition.effective_visual_variation(3, 3) != 0 or IslandDefinition.effective_visual_variation(1, 3) != 3:
		_fail("variation limit fallback is wrong")
		return
	var full_grid := IslandDefinition.new(112, 96)
	if full_grid.levels.size() != 10752 or full_grid.terrain_record_at(111, 95).size() != 7:
		_fail("observed RE grid dimensions cannot be represented without hard-coded island size")
		return
	var island := IslandDefinition.fixture_river()
	if island.terrain_record_at(5, 5) != [1, 2, 3, 1, 2, 0, 1]:
		_fail("seven-field terrain record was not encoded in both visual layers")
		return
	if not island.terrain_layer_at(6, 6, 1)["unit"] == 0:
		_fail("unspecified second layer should remain empty")
		return
	var saved: Dictionary = island.as_dictionary()
	if saved["schema_version"] != 7 or saved["terrain_layers"].size() != 2 or saved["occupants"].size() != saved["levels"].size() or saved["connectors"].size() != saved["levels"].size():
		_fail("v5 schema did not preserve terrain layers, occupants and connectors")
		return
	var recovered := IslandDefinition.from_dictionary(saved)
	if recovered.terrain_record_at(5, 5) != island.terrain_record_at(5, 5) or recovered.water != island.water:
		_fail("two-layer save round-trip lost variation, rotation, or river topology")
		return
	for old_version in [1, 2, 3, 4]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy["schema_version"] = old_version
		legacy.erase("connectors")
		if old_version < 4:
			legacy.erase("occupants")
		if old_version < 3:
			legacy.erase("terrain_layers")
		if old_version == 1:
			legacy.erase("water")
		var upgraded := IslandDefinition.from_dictionary(legacy)
		if old_version < 3 and (int(upgraded.terrain_layer_at(5, 5, 0)["unit"]) != 0 or int(upgraded.terrain_layer_at(5, 5, 1)["unit"]) != 0):
			_fail("legacy terrain was not initialized with empty material layers")
			return
		if old_version == 3 and upgraded.terrain_record_at(5, 5) != island.terrain_record_at(5, 5):
			_fail("schema v3 terrain was lost in v4 migration")
			return
		if upgraded.occupants.count(1) != 0:
			_fail("legacy occupants should default empty")
			return
		if upgraded.connectors.count(0) != upgraded.width * upgraded.depth:
			_fail("legacy connectors should default empty")
			return
		if old_version == 2 and upgraded.water != island.water:
			_fail("schema v2 river was not preserved")
			return
	var composer := IslandComposer.new(island)
	if not composer.cycle_terrain_layer(4, 4, 0, "unit"):
		_fail("surface material brush was rejected")
		return
	composer.cycle_terrain_layer(4, 4, 0, "variation")
	composer.cycle_terrain_layer(4, 4, 0, "rotation")
	composer.cycle_terrain_layer(4, 4, 1, "unit")
	var changed: Array[int] = island.terrain_record_at(4, 4)
	if changed.slice(0, 6) != [1, 1, 1, 1, 0, 0]:
		_fail("layer brush or variation/rotation update wrote wrong fields: " + str(changed))
		return
	if composer.cycle_terrain_layer(-1, 9, 0, "unit"):
		_fail("material brush allowed out-of-bounds edits")
		return
	var tile_center := Vector3(4.5 * IslandDefinition.TILE_SIZE + 0.25, 3.10, 4.5 * IslandDefinition.TILE_SIZE)
	var sampled_color: Color = TerrainBuilder._ground_color(island, 2, tile_center)
	var plain := IslandDefinition.new(island.width, island.depth)
	plain.set_height(4, 4, 2)
	var plain_color: Color = TerrainBuilder._ground_color(plain, 2, tile_center)
	if absf(sampled_color.r - plain_color.r) + absf(sampled_color.g - plain_color.g) < 0.08:
		_fail("surface layer edit changed metadata but not visible ground color")
		return
	var world := TerrainBuilder.build_world(island)
	if world.get_node_or_null("GroundDecorLayer") == null:
		_fail("second visual layer did not generate a terrain decal mesh")
		return
	if (world.get_node("WorldCollision") as StaticBody3D).get_child_count() != 2:
		_fail("cosmetic terrain layers unexpectedly replaced physical collider")
		return
	world.free()
	var target := "user://test_re_terrain_layers.json"
	if not composer.save_layout(target):
		_fail("schema v5 layout did not save")
		return
	composer.use_fixture(1)
	if not composer.load_layout(target) or composer.island.terrain_record_at(4, 4) != changed:
		_fail("schema v5 layout did not load the two layers losslessly")
		return
	# Malformed external layouts must never replace the working island.
	var unsafe: Dictionary = saved.duplicate(true)
	unsafe["terrain_layers"][0]["variation"][0] = 300
	var file := FileAccess.open("user://test_bad_re_layers.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(unsafe))
	file.close()
	var before: IslandDefinition = composer.island
	if composer.load_layout("user://test_bad_re_layers.json") or composer.island != before:
		_fail("unbounded variation was admitted to user save data")
		return
	print("PASS — two-layer records, reference height, v1/v2/v3/v4 → v5 migration, visual decals, input limits")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
