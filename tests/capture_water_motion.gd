extends SceneTree
## Captures a deterministic-resolution frame sequence to inspect shader movement.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/main.tscn")
	viewport.add_child(packed.instantiate())
	for index in range(12):
		for _i in range(9):
			await process_frame
		var shot: Image = viewport.get_texture().get_image()
		if shot == null or shot.is_empty():
			push_error("No rendered frame for motion sample: " + str(index))
			quit(2)
			return
		var target: String = ProjectSettings.globalize_path("res://water_frame_%02d.png" % index)
		if shot.save_png(target) != OK:
			push_error("Could not write water motion frame: " + target)
			quit(3)
			return
	print("Capture saved: 12 water motion frames (960x540)")
	quit(0)
