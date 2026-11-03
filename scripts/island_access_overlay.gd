class_name IslandAccessOverlay
extends RefCounted
## Unshaded translucent debug cells, grouped by dry walking component.

const PALETTE: Array[Color] = [
	Color(0.14, 0.98, 0.72, 0.55), Color(0.93, 0.31, 0.91, 0.55),
	Color(0.98, 0.73, 0.18, 0.55), Color(0.40, 0.67, 1.0, 0.55),
	Color(0.98, 0.40, 0.38, 0.55)
]


static func build(island: IslandDefinition, audit: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "AccessRegions"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var labels: PackedInt32Array = audit["labels"]
	var size: float = IslandDefinition.TILE_SIZE
	for z in range(island.depth):
		for x in range(island.width):
			var id: int = labels[z * island.width + x]
			if id < 0:
				continue
			var y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP + 0.085
			var a := Vector3((float(x) + 0.07) * size, y, (float(z) + 0.07) * size)
			var b := Vector3((float(x) + 0.93) * size, y, (float(z) + 0.07) * size)
			var c := Vector3((float(x) + 0.93) * size, y, (float(z) + 0.93) * size)
			var d := Vector3((float(x) + 0.07) * size, y, (float(z) + 0.93) * size)
			var tint: Color = PALETTE[id % PALETTE.size()]
			for vertex in [a, b, c, a, c, d]:
				tool.set_color(tint)
				tool.add_vertex(vertex)
	var mesh := tool.commit()
	var display := MeshInstance3D.new()
	display.name = "AccessTileColors"
	display.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	display.material_override = material
	root.add_child(display)
	return root
