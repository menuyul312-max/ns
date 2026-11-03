extends SceneTree
## Headless quantitative map preview. NOT a 3D viewport screenshot.
## Rasterizes the exact CPU land-mask + CoastBuilder SDF used by the ocean.

const WIDTH: int = 1400
const HEIGHT: int = 790
const PANEL_WIDTH: int = 630
const PANEL_HEIGHT: int = 660
const TOP: int = 70


func _initialize() -> void:
	call_deferred("_write_map")


func _write_map() -> void:
	var after: IslandDefinition = IslandDefinition.fixture_coast_mask()
	var before: IslandDefinition = IslandDefinition.from_dictionary(after.as_dictionary())
	for z in range(before.depth):
		for x in range(before.width):
			if not before.is_land(x, z):
				before.set_land(x, z, true)
	var frame := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	frame.fill(Color(0.043, 0.082, 0.12))
	_paint_map(frame, before, 44)
	_paint_map(frame, after, 726)
	if frame.save_png(ProjectSettings.globalize_path("res://s28_topdown_comparison.png")) != OK:
		push_error("Failed to save topology diagnostic")
		quit(2)
		return
	print("PASS MAP — CPU topology and shoreline-distance preview saved")
	quit(0)


func _paint_map(frame: Image, island: IslandDefinition, left: int) -> void:
	var sdf: Image = CoastBuilder.make_signed_coast_texture(island).get_image()
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var extent_x: float = w + 2.0 * CoastBuilder.SEA_MARGIN
	var extent_z: float = d + 2.0 * CoastBuilder.SEA_MARGIN
	for py in range(PANEL_HEIGHT):
		for px in range(PANEL_WIDTH):
			var wx: float = lerpf(-4.5, w + 4.5, float(px) / float(PANEL_WIDTH - 1))
			var wz: float = lerpf(-11.0, d + 11.0, float(py) / float(PANEL_HEIGHT - 1))
			var u: int = clampi(roundi((wx + CoastBuilder.SEA_MARGIN) / extent_x * float(sdf.get_width() - 1)), 0, sdf.get_width() - 1)
			var v: int = clampi(roundi((wz + CoastBuilder.SEA_MARGIN) / extent_z * float(sdf.get_height() - 1)), 0, sdf.get_height() - 1)
			var signed_distance: float = sdf.get_pixel(u, v).r
			var tone: Color
			if signed_distance > 0.0:
				var ocean_noise: float = 0.5 + 0.5 * sin(wx * 1.71 + wz * 1.23)
				tone = Color(0.035, 0.23, 0.36).lerp(Color(0.07, 0.37, 0.46), ocean_noise * 0.23)
				var wave: float = exp(-pow((signed_distance - 0.36) / 0.24, 2.0))
				var fragmented: float = smoothstep(0.02, 0.95, 0.5 + 0.5 * sin(wx * 2.36 + wz * 1.63))
				tone = tone.lerp(Color(0.54, 0.84, 0.82), 0.63 * wave * fragmented)
			else:
				var tx: int = floori(wx / IslandDefinition.TILE_SIZE)
				var tz: int = floori(wz / IslandDefinition.TILE_SIZE)
				var grass: float = 0.5 + 0.5 * sin(wx * 0.94 + wz * 0.35) * sin(wz * 1.07 - wx * 0.13)
				tone = Color(0.32, 0.63, 0.30).lerp(Color(0.43, 0.74, 0.36), grass * 0.65)
				if signed_distance > -0.74:
					tone = tone.lerp(Color(0.91, 0.81, 0.57), smoothstep(-0.74, -0.10, signed_distance))
				if island.height_at(tx, tz) > 0:
					tone = Color(0.19, 0.46, 0.26).lerp(tone, 0.35)
				if island.is_water(tx, tz):
					tone = Color(0.08, 0.49, 0.58)
				var local := Vector2(fposmod(wx / IslandDefinition.TILE_SIZE, 1.0), fposmod(wz / IslandDefinition.TILE_SIZE, 1.0))
				if island.occupant_at(tx, tz) == 1 and local.distance_to(Vector2(0.5, 0.5)) < 0.20:
					tone = Color(0.07, 0.31, 0.18)
				if island.occupant_at(tx, tz) == 2 and absf(local.x - 0.5) < 0.21 and absf(local.y - 0.5) < 0.21:
					tone = Color(0.77, 0.34, 0.20)
			frame.set_pixel(left + px, TOP + py, tone)
