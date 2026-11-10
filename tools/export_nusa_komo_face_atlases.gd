extends SceneTree
## Export the exact procedural pixels used by Godot's runtime face layers.


func _initialize() -> void:
	var output: String = ProjectSettings.globalize_path("res://generated/komo_atlases")
	DirAccess.make_dir_recursive_absolute(output)
	var layers := {
		"eye_left.png": NusaKomoFace._make_eyes(-1),
		"eye_right.png": NusaKomoFace._make_eyes(1),
		"mouth.png": NusaKomoFace._make_mouths(),
	}
	for name in layers:
		var png: Image = layers[name]
		var result: Error = png.save_png(output.path_join(name))
		if result != OK:
			push_error("Could not export %s: %d" % [name, result])
			quit(1)
			return
		print("NUSA_KOMO_ATLAS ", name, " ", png.get_size())
	quit(0)
