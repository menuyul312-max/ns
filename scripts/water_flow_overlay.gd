class_name WaterFlowOverlay
extends RefCounted
## Optional current arrows drawn over water surfaces for topology inspection.


static func build(island: IslandDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "CurrentDebug"
	var field := RiverContour.new(island)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrow_count: int = 0
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_water(x, z):
				continue
			var center := Vector2((float(x) + 0.5) * IslandDefinition.TILE_SIZE, (float(z) + 0.5) * IslandDefinition.TILE_SIZE)
			var direction: Vector2 = field.flow_at(center)
			if direction.length_squared() < 0.08:
				continue
			var perpendicular := Vector2(-direction.y, direction.x)
			var tail: Vector2 = center - direction * 0.31
			var body_end: Vector2 = center + direction * 0.16
			var tip: Vector2 = center + direction * 0.47
			var y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND + 0.086
			var color := Color(0.92, 0.97, 0.94, 0.77)
			_emit_triangle(tool, tail - perpendicular * 0.048, body_end - perpendicular * 0.048, body_end + perpendicular * 0.048, y, color)
			_emit_triangle(tool, tail - perpendicular * 0.048, body_end + perpendicular * 0.048, tail + perpendicular * 0.048, y, color)
			_emit_triangle(tool, body_end - perpendicular * 0.16, tip, body_end + perpendicular * 0.16, y, color)
			arrow_count += 1
	if arrow_count == 0:
		return root
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "FlowArrows"
	instance.mesh = tool.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 2
	instance.material_override = material
	root.add_child(instance)
	return root


static func _emit_triangle(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float, tint: Color) -> void:
	for point in [a, b, c]:
		tool.set_color(tint)
		tool.add_vertex(Vector3(point.x, y, point.y))
