extends SceneTree
## Runtime skeletal bone and collider audit, recorded as executable evidence.

func _initialize() -> void:
	call_deferred("_inspect")


func _inspect() -> void:
	var island := IslandDefinition.fixture_river()
	root.add_child(TerrainBuilder.build_world(island))
	root.add_child(WaterBuilder.build_world(island))
	var actor := RiverCharacter.new()
	actor.configure(island, WaterRules.new(island))
	root.add_child(actor)
	actor.set_start(5.5 * IslandDefinition.TILE_SIZE, 5.5 * IslandDefinition.TILE_SIZE)
	for _i in range(35):
		await physics_frame
	var rig: Skeleton3D = actor.rig_visual.skeleton
	print("skeleton world=", rig.global_transform, " actor=", actor.global_position)
	for index in rig.get_bone_count():
		var bone_name := String(rig.get_bone_name(index))
		if "Leg" in bone_name or "Foot" in bone_name or "Hips" in bone_name or "Root" in bone_name or "Toe" in bone_name:
			var parent_index: int = rig.get_bone_parent(index)
			print("BONE ", index, " ", bone_name, " parent=", rig.get_bone_name(parent_index) if parent_index >= 0 else "none", " rest_local=", rig.get_bone_rest(index).origin, " rest_global=", rig.get_bone_global_rest(index).origin, " current_local=", rig.get_bone_pose(index).origin, " current_global=", rig.get_bone_global_pose(index).origin, " world=", rig.global_transform * rig.get_bone_global_pose(index).origin)
	print("Probe: ", actor.foot_probe.foot_hits)
	quit()
