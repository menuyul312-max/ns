extends SceneTree
## Sprint 16: occupied landings, edit invariants and cosmetic geometry.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(5, 3)
	for z in range(3):
		for x in range(5):
			island.set_water(x, z, true)
	for x in [1, 3]:
		island.set_water(x, 1, false)
	island.set_occupant(1, 1, 1)
	var editor := IslandComposer.new(island)
	if editor.cycle_connector(2, 1) or editor.last_edit_report["code"] != "BANK_BLOCKED":
		_fail("bridge must reject a tree on its landing bank")
		return
	island.set_occupant(1, 1, 0)
	if not editor.cycle_connector(2, 1):
		_fail("cleared bridge must be placeable")
		return
	if editor.cycle_occupant(1, 1) or editor.last_edit_report["code"] != "LINK_LANDING":
		_fail("editing cannot put a tree on an active bridge landing")
		return
	# Candidate ramp on the bridge landing must not invalidate its neighbor.
	island.set_water(1, 0, false)
	island.set_height(1, 0, 1)
	if editor.cycle_connector(1, 1) or editor.last_edit_report["code"] != "LINK_CONFLICT":
		_fail("ramp must not occupy another connector's bank")
		return
	var bridge_mesh := IslandLinkBuilder.build_world(island)
	if bridge_mesh.get_node_or_null("Bridge_2_1/BilahKayu_00") == null or bridge_mesh.get_node_or_null("Bridge_2_1/TiangBambu") == null or bridge_mesh.get_node_or_null("Bridge_2_1/DeckCollision") == null:
		_fail("woven bridge visualization or physical collision missing")
		return
	bridge_mesh.free()
	var slope := IslandDefinition.new(5, 3)
	slope.set_height(2, 1, 1)
	slope.set_occupant(2, 1, 2)
	var ramp_editor := IslandComposer.new(slope)
	if ramp_editor.cycle_connector(1, 1) or ramp_editor.last_edit_report["code"] != "RAMP_LANDING_BLOCKED":
		_fail("ramp must reject an occupied upper landing")
		return
	slope.set_occupant(2, 1, 0)
	if not ramp_editor.cycle_connector(1, 1):
		_fail("ramp upper landing clear but editor refused link")
		return
	if ramp_editor.cycle_occupant(2, 1) or ramp_editor.last_edit_report["code"] != "LINK_LANDING":
		_fail("editor allowed building on ramp upper landing")
		return
	var ramp_mesh := IslandLinkBuilder.build_world(slope)
	if ramp_mesh.get_node_or_null("Ramp_1_1/BilahKayu_00") == null or ramp_mesh.get_node_or_null("Ramp_1_1/DeckCollision") == null:
		_fail("visual ramp boards or physical collider missing")
		return
	ramp_mesh.free()
	print("PASS — occupied landings, link conflicts, active-link safeguards, bamboo/wood joinery")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
