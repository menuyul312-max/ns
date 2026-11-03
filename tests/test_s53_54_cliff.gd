extends SceneTree
## Godot regression for the authored cliff profile. No Nintendo mesh data.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(6, 6)
	if TerrainBuilder.WALL_ROWS < 12 or TerrainBuilder.CORNER_ARC_MIX >= 0.62:
		_fail("cliff resolution/chamfer settings regressed")
		return
	for direction in range(4):
		for sample in range(21):
			var t: float = float(sample) / 20.0
			var lip: float = TerrainBuilder._lip_width(island, 2, 2, direction, t)
			if lip < 0.035 or lip > 0.21:
				_fail("grass lip outside bounded protrusion")
				return
			if not is_equal_approx(TerrainBuilder._wall_offset(island, 2, 2, direction, t, 0.0), lip):
				_fail("wall does not attach to grass lip at top")
				return
			if absf(TerrainBuilder._wall_offset(island, 2, 2, direction, t, 1.0)) > 0.00001:
				_fail("cliff bottom breaks terrain seam")
				return
			for row in range(1, TerrainBuilder.WALL_ROWS):
				var depth: float = float(row) / float(TerrainBuilder.WALL_ROWS)
				var offset: float = TerrainBuilder._wall_offset(island, 2, 2, direction, t, depth)
				if offset < -0.09 or offset > 0.45:
					_fail("rock ledge exceeds safe face relief")
					return
	for row in range(TerrainBuilder.WALL_ROWS + 1):
		var depth: float = float(row) / float(TerrainBuilder.WALL_ROWS)
		if not is_equal_approx(TerrainBuilder._wall_offset(island, 1, 3, 0, 1.0, depth), TerrainBuilder._wall_offset(island, 2, 3, 0, 0.0, depth)):
			_fail("north wall shared seam split")
			return
		if not is_equal_approx(TerrainBuilder._wall_offset(island, 3, 1, 1, 1.0, depth), TerrainBuilder._wall_offset(island, 3, 2, 1, 0.0, depth)):
			_fail("east wall shared seam split")
			return
	print("PASS — Sprint 53/54 lip attachment, ledge bounds, 12-row mesh and shared wall seam")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
