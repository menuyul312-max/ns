extends SceneTree
## Sprint 11 source-of-truth inspection for Godot's native limb solver.

func _initialize() -> void:
	for class_name_to_inspect in ["TwoBoneIK3D", "IKModifier3D", "SkeletonModifier3D"]:
		print("CLASS ", class_name_to_inspect, " exists=", ClassDB.class_exists(class_name_to_inspect))
		if ClassDB.class_exists(class_name_to_inspect):
			for item in ClassDB.class_get_method_list(class_name_to_inspect, true):
				print("  ", item["name"], " args=", item["args"])
	quit()
