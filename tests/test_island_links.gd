extends SceneTree
## Authored Nusantara one-tile bridges and low-to-high ramps.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var river := IslandDefinition.new(5, 3)
	for z in range(3):
		for x in range(5):
			river.set_water(x, z, true)
	river.set_water(1, 1, false)
	river.set_water(3, 1, false)
	var editor := IslandComposer.new(river)
	if IslandAccessAudit.analyze(river)["count"] != 2 or IslandLinkRules.find_new(river, 2, 1) != 5:
		_fail("bridge candidate between two dry equal-height endpoints not detected")
		return
	if not editor.cycle_connector(2, 1) or river.connector_at(2, 1) != 5:
		_fail("EW one-tile bridge creation failed")
		return
	var linked: Dictionary = IslandAccessAudit.analyze(river)
	if linked["count"] != 1 or linked["bridge_tiles"] != 1:
		_fail("bridge not integrated in walking graph")
		return
	var walk := WaterRules.new(river)
	var from := Vector3(1.5 * IslandDefinition.TILE_SIZE, 0.0, 1.5 * IslandDefinition.TILE_SIZE)
	var to := Vector3(3.5 * IslandDefinition.TILE_SIZE, 0.0, 1.5 * IslandDefinition.TILE_SIZE)
	if not walk.can_traverse_path(from, to, WaterRules.Mode.WALK):
		_fail("WALK cannot traverse the designated bridge centerline")
		return
	var bridge_center := Vector3(2.5 * IslandDefinition.TILE_SIZE, 0.0, 1.5 * IslandDefinition.TILE_SIZE)
	if walk.sample(bridge_center)["zone"] != WaterRules.Zone.LAND:
		_fail("bridge deck should mask water contact for WALK")
		return
	if walk.can_traverse_path(bridge_center, bridge_center + Vector3(0.0, 0.0, IslandDefinition.TILE_SIZE), WaterRules.Mode.WALK):
		_fail("bridge incorrectly connects lateral water cells")
		return
	var world := IslandLinkBuilder.build_world(river)
	if world.get_child_count() != 1 or (world.get_child(0) as StaticBody3D).collision_layer != 32 or world.get_node_or_null("Bridge_2_1/DeckCollision") == null:
		_fail("bridge render/collision proxy not built")
		return
	world.free()
	editor.protect_connectivity = true
	if editor.cycle_connector(2, 1) or editor.last_edit_report["code"] != "ACCESS_SPLIT":
		_fail("protected bridge was removed despite severing the only path")
		return
	if editor.toggle_water(2, 1) or editor.last_edit_report["code"] != "LINK_SUPPORT":
		_fail("river editing should not invalidate a bridge while it is installed")
		return
	var layout: String = "user://test_sprint15_bridge.json"
	if not editor.save_layout(layout):
		_fail("v5 bridge layout did not save")
		return
	var loaded := IslandComposer.new()
	if not loaded.load_layout(layout) or loaded.island.connector_at(2, 1) != 5:
		_fail("v5 bridge layout did not round-trip")
		return
	var invalid: Dictionary = river.as_dictionary()
	invalid["connectors"][0] = 99
	if not _reject(loaded, invalid, "user://s15_bad_link_range.json"):
		_fail("invalid v5 link type admitted")
		return
	invalid = river.as_dictionary()
	invalid["connectors"][1 + river.width] = 5
	if not _reject(loaded, invalid, "user://s15_bad_link_support.json"):
		_fail("bridge with no supporting endpoints admitted")
		return
	var legacy: Dictionary = river.as_dictionary()
	legacy["schema_version"] = 4
	legacy.erase("connectors")
	if IslandDefinition.from_dictionary(legacy).connector_at(2, 1) != 0:
		_fail("v4 migration should have empty connectors")
		return
	var slope := IslandDefinition.new(5, 3)
	slope.set_height(2, 1, 1)
	var ramp_editor := IslandComposer.new(slope)
	if IslandAccessAudit.analyze(slope)["count"] != 2 or IslandLinkRules.find_new(slope, 1, 1) != 2:
		_fail("ramp candidate not identified at low edge of cliff")
		return
	if not ramp_editor.cycle_connector(1, 1) or slope.connector_at(1, 1) != 2:
		_fail("ramp creation failed")
		return
	if IslandAccessAudit.analyze(slope)["count"] != 1:
		_fail("ramp did not merge the two elevation components")
		return
	var slope_walk := WaterRules.new(slope)
	from = Vector3(1.5 * IslandDefinition.TILE_SIZE, 0.0, 1.5 * IslandDefinition.TILE_SIZE)
	to = Vector3(2.5 * IslandDefinition.TILE_SIZE, 0.0, 1.5 * IslandDefinition.TILE_SIZE)
	if not slope_walk.can_traverse_path(from, to, WaterRules.Mode.WALK):
		_fail("WALK path cannot cross valid low-to-high ramp")
		return
	if ramp_editor.modify_tile(2, 1, -1) or ramp_editor.last_edit_report["code"] != "LINK_SUPPORT":
		_fail("cliff change unexpectedly invalidated installed ramp")
		return
	if ramp_editor.cycle_occupant(1, 1) or ramp_editor.last_edit_report["code"] != "LINK_OCCUPIED":
		_fail("tree allowed directly on a ramp")
		return
	world = IslandLinkBuilder.build_world(slope)
	if world.get_node_or_null("Ramp_1_1/DeckCollision") == null:
		_fail("ramp collision geometry missing")
		return
	world.free()
	print("PASS — bridge and ramp connectors, walk graph, water masking, v5 data, support invariants")
	quit(0)


func _reject(editor: IslandComposer, data: Dictionary, path: String) -> bool:
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
