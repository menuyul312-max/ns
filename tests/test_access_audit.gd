extends SceneTree
## Graph reachability is a Nusantara design rule, not recovered ACNH logic.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := IslandDefinition.new(7, 5)
	for z in range(bridge.depth):
		for x in range(bridge.width):
			bridge.set_water(x, z, true)
	for x in range(1, 6):
		bridge.set_water(x, 2, false)
	var before: Dictionary = IslandAccessAudit.analyze(bridge)
	if before["count"] != 1 or before["largest"] != 5 or before["dry_tiles"] != 5:
		_fail("baseline corridor graph incorrect")
		return
	var risk: Dictionary = IslandAccessAudit.preview_change(bridge, 3, 2, 0, true)
	if risk["allowed"] or risk["code"] != "ACCESS_SPLIT" or risk["after_regions"] != 2:
		_fail("removing center bridge should disconnect unchanged banks")
		return
	if bridge.is_water(3, 2):
		_fail("preview mutated live map")
		return
	var editor := IslandComposer.new(bridge)
	if editor.protect_connectivity:
		_fail("connectivity protection should default OFF")
		return
	if not editor.toggle_water(3, 2):
		_fail("OFF mode broke existing editing behavior")
		return
	bridge.set_water(3, 2, false)
	editor.protect_connectivity = true
	if editor.toggle_water(3, 2) or editor.last_edit_report["code"] != "ACCESS_SPLIT":
		_fail("ON mode failed to reject a destructive river split")
		return
	if editor.modify_tile(3, 2, 1) or editor.last_edit_report["code"] != "ACCESS_SPLIT":
		_fail("ON mode failed to reject cliff bottleneck")
		return
	if not editor.modify_tile(1, 2, 1):
		_fail("safe edge tile elevation should remain editable")
		return
	if bridge.height_at(1, 2) != 1 or bridge.height_at(2, 2) != 0:
		_fail("safe edit modified more than its target")
		return
	# Existing disconnected plateaus aren't grounds to reject all edits.
	bridge.set_water(5, 4, false)
	var disconnected: Dictionary = IslandAccessAudit.analyze(bridge)
	if disconnected["count"] != 3:
		_fail("preexisting isolated patch was not counted")
		return
	if not editor.modify_tile(5, 4, 1):
		_fail("editing a separate region was wrongly prohibited")
		return
	# A bypass makes the same river removal safe: old residents stay linked.
	bridge.set_height(1, 2, 0)
	for x in [2, 3, 4]:
		bridge.set_water(x, 1, false)
	var bypass_result: Dictionary = IslandAccessAudit.preview_change(bridge, 3, 2, 0, true)
	if not bypass_result["allowed"]:
		_fail("alternate dry route should avoid false split")
		return
	if not editor.toggle_water(3, 2):
		_fail("bridge removal with bypass should pass")
		return
	bridge.set_occupant(5, 4, 1)
	if editor.toggle_water(5, 4) or editor.last_edit_report["code"] != "FEATURE_ON_WATER":
		_fail("editor allowed river beneath a tree despite schema v4 invariant")
		return
	bridge.set_occupant(5, 4, 0)
	var overlay := IslandAccessOverlay.build(bridge, IslandAccessAudit.analyze(bridge))
	if overlay.get_node_or_null("AccessTileColors") == null:
		_fail("colored region overlay missing")
		return
	overlay.free()
	var big := IslandDefinition.new(112, 96)
	var giant: Dictionary = IslandAccessAudit.analyze(big)
	if giant["count"] != 1 or giant["largest"] != 10752:
		_fail("full-size RE study grid was hardcoded/truncated")
		return
	print("PASS — dry graph, bridge and cliff splits, bypass, isolated regions, overlay, 112x96")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
