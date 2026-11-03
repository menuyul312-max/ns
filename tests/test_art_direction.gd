extends SceneTree
## Visual-geometry invariants are checked numerically before image review.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(14, 10)
	var tile: float = IslandDefinition.TILE_SIZE
	var meadow: Color = TerrainBuilder._ground_color(island, 0, Vector3(8.0 * tile, 0, 5.0 * tile))
	var beach: Color = TerrainBuilder._ground_color(island, 0, Vector3(0.22 * tile, 0, 5.0 * tile))
	if meadow.g < meadow.r + 0.09 or beach.r < beach.g + 0.04:
		_fail("grass interior / sandy coast visual classification regressed")
		return
	for z in range(10):
		for x in range(4, 7):
			island.set_water(x, z, true)
	if RiverContour.field_at(island, 5.5 * tile, 0.02, 0) < RiverContour.THRESHOLD:
		_fail("river mouth still rounds off before the coastal sea")
		return
	var hydrology := WaterBuilder.build_world(island)
	var shoreline: MeshInstance3D = hydrology.get_node_or_null("ShoreFoam")
	var banks: MeshInstance3D = hydrology.get_node_or_null("RiverBanks")
	if shoreline == null or banks == null:
		_fail("graded shoreline foam and bank meshes were missing")
		return
	var water_shader: ShaderMaterial = hydrology.get_node("WaterSurface").material_override
	if not water_shader.shader.code.contains("COLOR.rg * 2.0 - 1.0") or not water_shader.shader.code.contains("wave_dir"):
		_fail("flow-aligned, finite wavelets are missing")
		return
	var foam_colors: PackedColorArray = shoreline.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var bank_colors: PackedColorArray = banks.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var max_foam: float = 0.0
	var min_foam: float = 1.0
	for color in foam_colors:
		max_foam = maxf(max_foam, color.a)
		min_foam = minf(min_foam, color.a)
	if max_foam < 0.15 or min_foam > 0.01:
		_fail("shore wash lost its alpha fade")
		return
	var min_bank: float = 1.0
	var max_bank: float = 0.0
	for color in bank_colors:
		min_bank = minf(min_bank, color.g)
		max_bank = maxf(max_bank, color.g)
	if max_bank - min_bank < 0.06:
		_fail("bank lost wet-to-dry pigment gradient")
		return
	hydrology.free()
	var terrace := IslandDefinition.new(4, 4)
	for z in range(1, 3):
		for x in range(1, 3):
			terrace.set_height(x, z, 1)
	var terrain := TerrainBuilder.build_world(terrace)
	var cliff: MeshInstance3D = terrain.get_node_or_null("CliffFaces")
	if cliff == null or terrain.get_node_or_null("WorldCollision") == null:
		_fail("cliff shading geometry or collider missing")
		return
	var cliff_colors: PackedColorArray = cliff.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var min_cliff: float = 1.0
	var max_cliff: float = 0.0
	for color in cliff_colors:
		min_cliff = minf(min_cliff, color.r)
		max_cliff = maxf(max_cliff, color.r)
	if max_cliff - min_cliff < 0.14:
		_fail("vertical cliff strata lost color depth")
		return
	terrain.free()
	var waterfall_island := IslandDefinition.fixture_river()
	var opening: Vector2 = WaterBuilder._fall_interval(waterfall_island, 8, 3, 1, 1, 0)
	if opening.y - opening.x < 0.36:
		_fail("waterfall curtain is a tiny rectangular sliver: %s" % str(opening))
		return
	var plunge := WaterBuilder.build_world(waterfall_island)
	var fall_foam: MeshInstance3D = plunge.get_node_or_null("FallFoam")
	if fall_foam == null or fall_foam.mesh.get_surface_count() < 1:
		_fail("waterfall splash apron disappeared")
		return
	var splash_colors: PackedColorArray = fall_foam.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var strongest: float = 0.0
	for color in splash_colors:
		strongest = maxf(strongest, color.a)
	if strongest < 0.25:
		_fail("splash apron lacks visible opacity")
		return
	plunge.free()
	var coast := CoastBuilder.build_world(island)
	var ocean_mesh: MeshInstance3D = coast.get_node_or_null("OceanSurface")
	if ocean_mesh == null or ocean_mesh.mesh.get_surface_count() != 1 or not ocean_mesh.material_override is ShaderMaterial:
		_fail("non-interactive ocean ring must be generated with one world-space shader")
		return
	if not ocean_mesh.material_override.shader.code.contains("water_distance") or not ocean_mesh.material_override.shader.code.contains("coast_profile"):
		_fail("ocean lost its deformable shoreline distance modulation")
		return
	if coast.get_node_or_null("CollisionShape3D") != null:
		_fail("decorative coast must not affect the gameplay collider")
		return
	coast.free()
	print("PASS — meadow coast, flow wavelets, fading shore, rock strata, waterfall span %s, splash apron" % str(opening))
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
