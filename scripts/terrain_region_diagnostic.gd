class_name TerrainRegionDiagnostic
extends Control
## Sprint 48: READ-ONLY visual probe of a synthetic Nusantara->RE grid.
## The RE functions are bounded; these projected word/height values are our
## own demo inputs and must never gate real terraforming or actor collision.

const CELL_PIXELS: float = 13.0
const PADDING: float = 15.0
const COLORS: Array[Color] = [
	Color("2b5874"), # no land (outside studied grid surface)
	Color("39a6bc"), # synthetic river overlay
	Color("78c681"), # area check passes
	Color("e9aa63"), # area check fails
]

var _mask := PackedByteArray()
var _map_width: int = 0
var _map_depth: int = 0
var _mode: int = 0
var _counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])


static func project(island: IslandDefinition) -> NativeTerrainRegionReference:
	var grid := NativeTerrainRegionReference.new(island.width, island.depth)
	for z in range(island.depth):
		for x in range(island.width):
			if not island.is_land(x, z):
				continue
			# This record is SYNTHETIC: first height uses Nusantara's own
			# elevation scale; no claim that ACNH uses this tile convention.
			var base_height: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP
			var wet: bool = island.is_water(x, z)
			# Deliberate scenario to demonstrate base/overlay difference:
			# water is represented as an active first-attribute overlay +0.16.
			grid.set_sample(x, z, 0x1f03, base_height, base_height + 0.16 if wet else 0.0, 0 if wet else NativeTerrainRegionReference.INHERIT)
	return grid


static func evaluate(island: IslandDefinition, mode: int) -> Dictionary:
	assert(mode == 0 or mode == 1)
	var grid := project(island)
	var statuses := PackedByteArray()
	statuses.resize(island.width * island.depth)
	var counts := PackedInt32Array([0, 0, 0, 0])
	for z in range(island.depth):
		for x in range(island.width):
			var status: int = 0
			if island.is_land(x, z):
				if island.is_water(x, z):
					status = 1
				elif grid.check_height_region(Vector2i(x - 1, z - 1), Vector2i(x + 1, z + 1), mode):
					status = 2
				else:
					status = 3
			statuses[z * island.width + x] = status
			counts[status] += 1
	return {"statuses": statuses, "counts": counts, "mode": mode, "source": "synthetic_nusantara_projection"}


func configure(island: IslandDefinition, mode: int) -> void:
	_map_width = island.width
	_map_depth = island.depth
	_mode = mode
	var result: Dictionary = evaluate(island, mode)
	_mask = result["statuses"]
	_counts = result["counts"]
	custom_minimum_size = Vector2(float(_map_width) * CELL_PIXELS + PADDING * 2.0, float(_map_depth) * CELL_PIXELS + 112.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if _mask.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.12, 0.16, 0.92), true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(PADDING, 23), "RE REGION • MODE %d" % _mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(font, Vector2(PADDING, 41), "Synthetic inputs / 3×3 inclusive", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c1d9d4"))
	for z in range(_map_depth):
		for x in range(_map_width):
			var status: int = _mask[z * _map_width + x]
			var area := Rect2(Vector2(PADDING + float(x) * CELL_PIXELS, 51.0 + float(z) * CELL_PIXELS), Vector2(CELL_PIXELS - 1.0, CELL_PIXELS - 1.0))
			draw_rect(area, COLORS[status], true)
	var footer_y: float = 70.0 + float(_map_depth) * CELL_PIXELS
	draw_string(font, Vector2(PADDING, footer_y), "pass %d  blocked %d  river %d" % [_counts[2], _counts[3], _counts[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(font, Vector2(PADDING, footer_y + 19), "[J] show/hide   [H] mode 0/1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f3d8a6"))
