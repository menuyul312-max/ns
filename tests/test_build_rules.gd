extends SceneTree
## Sprint 13: independent, opt-in guard tests. Do not interpret as exact ACNH behavior.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(8, 8)
	for z in range(8):
		for x in range(8):
			island.set_height(x, z, 2)
	var editor := IslandComposer.new(island)
	if editor.strict_build_rules:
		_fail("strict build rules should default OFF")
		return
	island.set_occupant(3, 3, 1)
	if not editor.modify_tile(4, 4, 1):
		_fail("permissive editing broke legacy behavior")
		return
	island.set_height(4, 4, 2)
	editor.strict_build_rules = true
	if editor.modify_tile(4, 4, 1) or editor.last_edit_report["code"] != "TREE_NEAR_EDIT":
		_fail("diagonal tree did not block 3x3 context")
		return
	if island.height_at(4, 4) != 2:
		_fail("denied edit mutated the tile")
		return
	if not editor.modify_tile(5, 5, 1):
		_fail("tree outside radius 1 blocked editing")
		return
	if island.height_at(4, 4) != 2 or island.height_at(5, 5) != 3:
		_fail("context check incorrectly edited all nine cells")
		return
	if editor.modify_tile(3, 3, 1) or editor.last_edit_report["code"] != "OCCUPIED_TILE":
		_fail("own occupied tile was not blocked")
		return
	island.set_occupant(3, 3, 2)
	if editor.toggle_water(3, 4) or editor.last_edit_report["code"] != "BUILDING_NEAR_EDIT":
		_fail("nearby structure did not block channel editing")
		return
	island.set_occupant(3, 3, 0)
	island.set_water(2, 2, true)
	if editor.modify_tile(2, 3, -1) or editor.last_edit_report["code"] != "CLIFF_NEAR_WATER":
		_fail("nearby water did not guard cliff removal")
		return
	if not editor.toggle_water(2, 2) or island.is_water(2, 2):
		_fail("water removal should be allowed to resolve invalid topology")
		return
	island.set_water(2, 2, true)
	island.set_water(2, 3, true)
	island.set_height(2, 2, 3)
	if editor.modify_tile(3, 3, 1) or editor.last_edit_report["code"] != "WATERFALL_NEAR_EDIT":
		_fail("nearby waterfall did not trigger change guard")
		return
	if not editor.cycle_occupant(6, 6) or island.occupant_at(6, 6) != 1:
		_fail("tree placement failed")
		return
	if not editor.cycle_occupant(6, 6) or island.occupant_at(6, 6) != 2:
		_fail("tree→stilt house transition failed")
		return
	var feature_world := TerrainBuilder.build_world(island)
	var feature_root: Node3D = feature_world.get_node("TileOccupants")
	if feature_root.get_child_count() != 1:
		_fail("new prop did not produce a visible object")
		return
	var prop: StaticBody3D = feature_root.get_child(0)
	if prop.collision_layer != 16 or prop.get_node_or_null("FeatureCollision") == null:
		_fail("original prop collider not isolated from edit ray")
		return
	feature_world.free()
	island.set_water(1, 1, true)
	if editor.cycle_occupant(1, 1) or island.occupant_at(1, 1) != 0:
		_fail("prop was allowed on water")
		return
	var target: String = "user://test_sprint15_rules.json"
	if not editor.save_layout(target):
		_fail("schema v5 did not save")
		return
	var restored := IslandComposer.new()
	if not restored.load_layout(target) or restored.island.occupant_at(6, 6) != 2:
		_fail("schema v5 lost structure occupancy")
		return
	var invalid: Dictionary = island.as_dictionary()
	invalid["occupants"][0] = 3
	if not _rejected_invalid(restored, invalid, "user://s13_invalid_occupant.json"):
		_fail("out-of-range occupant passed save validation")
		return
	invalid = island.as_dictionary()
	invalid["occupants"][1 + island.width] = 1
	if not _rejected_invalid(restored, invalid, "user://s13_invalid_water_occupant.json"):
		_fail("occupancy on river passed save validation")
		return
	var legacy: Dictionary = island.as_dictionary()
	legacy["schema_version"] = 3
	legacy.erase("occupants")
	legacy.erase("connectors")
	var migrated := IslandDefinition.from_dictionary(legacy)
	if migrated.occupant_at(6, 6) != 0 or migrated.terrain_record_at(5, 5) != island.terrain_record_at(5, 5):
		_fail("v3 migration did not safely reset occupancy")
		return
	print("PASS — opt-in 3x3 guard, trees/houses, waterfall, v5 persistence, v3 migration, prop collision")
	quit(0)


func _rejected_invalid(editor: IslandComposer, data: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var original: IslandDefinition = editor.island
	return not editor.load_layout(path) and editor.island == original


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
