extends SceneTree
## Sprint 17: one atomic 1..3-cell bridge, graph, collider, persisted span.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(10, 5)
	for z in range(5):
		for x in range(3, 6):
			island.set_water(x, z, true)
	var editor := IslandComposer.new(island)
	if IslandAccessAudit.analyze(island)["count"] != 2 or IslandLinkRules.find_new(island, 4, 2) != 5:
		_fail("three-water-cell bridge site not recognized")
		return
	if not editor.cycle_connector(4, 2):
		_fail("multi-tile bridge rejected: %s" % editor.last_edit_report)
		return
	for x in range(3, 6):
		if island.connector_at(x, 2) != 5 or not IslandLinkRules.is_valid(island, x, 2, 5):
			_fail("water tile %d not stamped or link invalid" % x)
			return
	var report: Dictionary = IslandAccessAudit.analyze(island)
	if report["count"] != 1 or report["bridge_tiles"] != 3:
		_fail("multi-span bridge not merged in walking graph")
		return
	var rule := WaterRules.new(island)
	var a := Vector3(2.5 * IslandDefinition.TILE_SIZE, 0, 2.5 * IslandDefinition.TILE_SIZE)
	var b := Vector3(6.5 * IslandDefinition.TILE_SIZE, 0, 2.5 * IslandDefinition.TILE_SIZE)
	if not rule.can_traverse_path(a, b, WaterRules.Mode.WALK):
		_fail("WALK cannot cross the centerline of three-cell bridge")
		return
	var world := IslandLinkBuilder.build_world(island)
	if world.get_child_count() != 1 or world.get_node_or_null("Bridge_3_2/DeckCollision") == null or world.get_node_or_null("Bridge_3_2/BankApronA") == null or world.get_node_or_null("Bridge_3_2/BankApronB") == null or world.get_node_or_null("Bridge_3_2/BilahKayu_35") == null:
		_fail("bridge must be one physical span with 36 boards and two tapered aprons")
		return
	world.free()
	var save_path := "user://s17_span.json"
	if not editor.save_layout(save_path):
		_fail("span save failed")
		return
	var reloaded := IslandComposer.new()
	if not reloaded.load_layout(save_path) or reloaded.island.connector_at(5, 2) != 5:
		_fail("schema v5 span did not round-trip")
		return
	if editor.modify_tile(2, 2, 1) or editor.last_edit_report["code"] != "LINK_SUPPORT":
		_fail("raising a bridge bank must not invalidate a supported span")
		return
	editor.protect_connectivity = true
	if editor.cycle_connector(5, 2) or editor.last_edit_report["code"] != "ACCESS_SPLIT":
		_fail("protected span should reject removal that cuts the island")
		return
	for x in range(3, 6):
		if island.connector_at(x, 2) != 5:
			_fail("protected removal partially modified a span")
			return
	editor.protect_connectivity = false
	if not editor.cycle_connector(5, 2) or IslandAccessAudit.analyze(island)["count"] != 2:
		_fail("removing a span must clear all its cells atomically")
		return
	for x in range(3, 6):
		if island.connector_at(x, 2) != 0:
			_fail("deleted span left a bridge marker")
			return
	# A four-cell span is beyond this controlled prototype's geometry budget.
	for z in range(5):
		island.set_water(6, z, true)
	var rejection: Dictionary = IslandLinkRules.placement_report(island, 4, 2)
	if rejection["allowed"] or rejection["code"] != "SPAN_TOO_LONG":
		_fail("span longer than three water cells must be rejected")
		return
	print("PASS — atomic 3-tile bridge, graph, physical mesh, aprons, v5 save, bank support, protected edit")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
