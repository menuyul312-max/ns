class_name WaterZoneOverlay
extends RefCounted
## Optional editor-only heatmap. Warm = near shoreline; cyan = channel interior.

const SAMPLES_PER_TILE: int = 10


static func build(island: IslandDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "WaterZoneDebug"
	var contour := RiverContour.new(island)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles: int = 0
	var step: float = IslandDefinition.TILE_SIZE / float(SAMPLES_PER_TILE)
	for level in contour.wet_levels():
		var y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND + 0.048
		for gz in range(island.depth * SAMPLES_PER_TILE):
			for gx in range(island.width * SAMPLES_PER_TILE):
				var x0: float = float(gx) * step
				var z0: float = float(gz) * step
				var points: Array[Vector2] = [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
				var fields: Array[float] = []
				for point in points:
					fields.append(RiverContour.field_at(island, point.x, point.y, level))
				if maxf(maxf(fields[0], fields[1]), maxf(fields[2], fields[3])) < RiverContour.THRESHOLD:
					continue
				for triangle in [[0, 1, 2], [0, 2, 3]]:
					var clipped: Dictionary = RiverContour._clip_triangle([points[triangle[0]], points[triangle[1]], points[triangle[2]]], [fields[triangle[0]], fields[triangle[1]], fields[triangle[2]]])
					var polygon: Array[Vector2] = clipped["polygon"]
					for i in range(1, polygon.size() - 1):
						_add_vertex(tool, island, polygon[0], level, y)
						_add_vertex(tool, island, polygon[i], level, y)
						_add_vertex(tool, island, polygon[i + 1], level, y)
						triangles += 1
	if triangles == 0:
		return root
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "WaterDepthZones"
	instance.mesh = tool.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	instance.material_override = material
	root.add_child(instance)
	return root


static func _add_vertex(tool: SurfaceTool, island: IslandDefinition, p: Vector2, level: int, y: float) -> void:
	var depth: float = RiverBathymetry.depth_at(island, p.x, p.y, level)
	var blend: float = smoothstep(0.08, 0.68, depth)
	var warm := Color(0.98, 0.65, 0.18, 0.62)
	var deep := Color(0.09, 0.78, 0.91, 0.44)
	tool.set_color(warm.lerp(deep, blend))
	tool.add_vertex(Vector3(p.x, y, p.y))
