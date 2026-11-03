extends SceneTree
## Behavioral contract for the curved beach-distance cache. Requires Godot 4.7+.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(9, 9)
	island.set_land(4, 4, false)
	var tile: float = IslandDefinition.TILE_SIZE
	CoastContour.prepare_shoreline_cache(island)
	var sea_corner: Vector2 = Vector2(4.0 * tile + 0.04, 4.0 * tile + 0.04)
	var middle_of_bay: Vector2 = Vector2(4.5 * tile, 4.5 * tile)
	if not CoastContour.on_island(island, sea_corner.x, sea_corner.y):
		_fail("concave fillet traversal is no longer available")
		return
	if CoastContour.on_island(island, middle_of_bay.x, middle_of_bay.y):
		_fail("shore cache erroneously closed water cell")
		return
	var sand_distance: float = CoastContour.distance_to_coast(island, middle_of_bay.x, middle_of_bay.y)
	if sand_distance < 0.12 or sand_distance > 1.5:
		_fail("beach distance not measured to the actual inlet: %.4f" % sand_distance)
		return
	# Use the same shoreline coordinates that the real skirt mesh emits.
	var rounded: Array[bool] = [false, false, false, false]
	var bounds: Vector2 = TerrainBuilder._shore_edge_bounds(island, 4, 3, 2, rounded)
	var contour_vertex: Vector3 = TerrainBuilder._edge_position(4, 3, 2, 0.5 * (bounds.x + bounds.y), 0.0, 0.0)
	contour_vertex = CoastContour.warp_ground(island, contour_vertex, 0)
	if CoastContour.distance_to_coast(island, contour_vertex.x, contour_vertex.z) > 0.035:
		_fail("actual shore skirt and beach distance drifted apart")
		return
	var revision: int = island.coastline_revision
	island.set_land(4, 4, true)
	if island.coastline_revision <= revision:
		_fail("mask editor did not invalidate cache")
		return
	if CoastContour.distance_to_coast(island, middle_of_bay.x, middle_of_bay.y) < 3.35:
		_fail("deleted cove persisted after filling its mask cell")
		return
	island.set_land(4, 4, false)
	revision = island.coastline_revision
	island.set_water(3, 4, true)
	if island.coastline_revision <= revision or TerrainBuilder._is_concave_mask_corner(island, 4, 4, 0):
		_fail("wet river bank was not excluded from fillet cache")
		return
	print("PASS — true curved shoreline distance; shared skirt; edit invalidation; wet outlet")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
