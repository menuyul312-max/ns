class_name RiverBathymetry
extends RefCounted
## Analytical riverbed profile shared by terrain mesh and gameplay queries.
## Values are original to this Nusantara prototype, not ACNH measurements.

const LOWER_BAND: float = 0.36
const CHANNEL_ADDITION: float = 0.48


static func depression_at(island: IslandDefinition, x: float, z: float, level: int) -> float:
	var coverage: float = RiverContour.field_at(island, x, z, level)
	return LOWER_BAND * smoothstep(0.27, 0.78, coverage) + CHANNEL_ADDITION * smoothstep(0.68, 0.98, coverage)


static func floor_height_at(island: IslandDefinition, x: float, z: float, level: int) -> float:
	return float(level) * IslandDefinition.HEIGHT_STEP - depression_at(island, x, z, level)


static func depth_at(island: IslandDefinition, x: float, z: float, level: int) -> float:
	var coverage: float = RiverContour.field_at(island, x, z, level)
	if coverage < RiverContour.THRESHOLD:
		return 0.0
	var water_y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND
	return maxf(0.0, water_y - floor_height_at(island, x, z, level))
