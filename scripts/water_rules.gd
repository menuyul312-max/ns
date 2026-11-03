class_name WaterRules
extends RefCounted
## Original gameplay queries built on Sprint 04's shared water contour.
## "Deep" means interior channel (distance from shore), not measured bathymetry.

enum Zone { LAND, BANK, SHALLOW, DEEP }
enum Mode { WALK, WADE, SWIM }

const BANK_BAND: float = 0.23
const DEEP_DEPTH: float = 0.39
const MAX_SHORE_SEARCH: float = 1.56
const SHORE_STEP: float = 0.12
const RAY_COUNT: int = 16
const PATH_STEP: float = 0.095

var island: IslandDefinition
var contour: RiverContour


func _init(source: IslandDefinition) -> void:
	island = source
	contour = RiverContour.new(source)


func sample(feet: Vector3) -> Dictionary:
	var position := Vector2(feet.x, feet.z)
	var level: int = clampi(roundi((feet.y - WaterBuilder.WATER_ABOVE_GROUND) / IslandDefinition.HEIGHT_STEP), 0, 5)
	var surface_y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND
	if IslandLinkRules.on_bridge_deck(island, feet.x, feet.z):
		return {"zone": Zone.LAND, "label": "JEMBATAN", "water": false, "shore_distance": MAX_SHORE_SEARCH, "depth": 0.0, "level": level, "surface_y": surface_y, "flow": Vector2.ZERO}
	var coverage: float = RiverContour.field_at(island, position.x, position.y, level)
	var is_wet: bool = coverage >= RiverContour.THRESHOLD
	var shore_distance: float = _shore_distance(position, level, is_wet)
	var water_depth: float = RiverBathymetry.depth_at(island, position.x, position.y, level)
	var zone: Zone = Zone.LAND
	if is_wet:
		zone = Zone.SHALLOW if water_depth <= DEEP_DEPTH else Zone.DEEP
	elif shore_distance <= BANK_BAND:
		zone = Zone.BANK
	return {
		"zone": zone,
		"label": zone_name(zone),
		"water": is_wet,
		"shore_distance": shore_distance,
		"depth": water_depth,
		"level": level,
		"surface_y": surface_y,
		"flow": contour.flow_at(position) if is_wet else Vector2.ZERO
	}


func can_traverse_path(origin: Vector3, destination: Vector3, mode: Mode) -> bool:
	# Small fixed samples prevent a quick movement tick from skipping narrow water.
	var distance: float = Vector2(origin.x, origin.z).distance_to(Vector2(destination.x, destination.z))
	var segments: int = maxi(1, ceili(distance / PATH_STEP))
	var original_cell := Vector2i(floori(origin.x / IslandDefinition.TILE_SIZE), floori(origin.z / IslandDefinition.TILE_SIZE))
	if not island.contains(original_cell.x, original_cell.y):
		return false
	var previous_cell: Vector2i = original_cell
	for index in range(segments + 1):
		var t: float = float(index) / float(segments)
		var current: Vector3 = origin.lerp(destination, t)
		if not CoastContour.on_island(island, current.x, current.z):
			return false
		var x: int = floori(current.x / IslandDefinition.TILE_SIZE)
		var z: int = floori(current.z / IslandDefinition.TILE_SIZE)
		if not island.contains(x, z):
			return false
		var cell := Vector2i(x, z)
		if cell != previous_cell:
			var old_height: int = island.height_at(previous_cell.x, previous_cell.y)
			var new_height: int = island.height_at(x, z)
			var requires_link: bool = old_height != new_height
			if mode == Mode.WALK and (island.is_water(previous_cell.x, previous_cell.y) or island.is_water(x, z)):
				requires_link = true
			if requires_link and not IslandLinkRules.walk_edge(island, previous_cell, cell):
				return false
			previous_cell = cell
		var level: int = island.height_at(x, z)
		var zone: Zone = sample(Vector3(current.x, float(level) * IslandDefinition.HEIGHT_STEP, current.z))["zone"]
		if not can_enter(zone, mode):
			return false
	return true


static func can_enter(zone: Zone, mode: Mode) -> bool:
	match mode:
		Mode.WALK:
			return zone == Zone.LAND or zone == Zone.BANK
		Mode.WADE:
			return zone != Zone.DEEP
		Mode.SWIM:
			return true
	return false


static func zone_name(zone: Zone) -> String:
	match zone:
		Zone.LAND:
			return "DARAT"
		Zone.BANK:
			return "TEPI"
		Zone.SHALLOW:
			return "DANGKAL"
		Zone.DEEP:
			return "ALUR DALAM"
	return "?"


static func mode_name(mode: Mode) -> String:
	match mode:
		Mode.WALK:
			return "JALAN"
		Mode.WADE:
			return "RENDAM"
		Mode.SWIM:
			return "RENANG"
	return "?"


func _shore_distance(position: Vector2, level: int, inside: bool) -> float:
	var closest: float = MAX_SHORE_SEARCH
	for ray in range(RAY_COUNT):
		var direction: Vector2 = Vector2.from_angle(TAU * float(ray) / float(RAY_COUNT))
		var previous: float = 0.0
		for step in range(1, ceili(MAX_SHORE_SEARCH / SHORE_STEP) + 1):
			var distance: float = minf(MAX_SHORE_SEARCH, float(step) * SHORE_STEP)
			if distance >= closest:
				break
			var target: Vector2 = position + direction * distance
			var sample_inside: bool = RiverContour.field_at(island, target.x, target.y, level) >= RiverContour.THRESHOLD
			if sample_inside != inside:
				var low: float = previous
				var high: float = distance
				for _i in range(6):
					var middle: float = (low + high) * 0.5
					var mid_position: Vector2 = position + direction * middle
					var mid_inside: bool = RiverContour.field_at(island, mid_position.x, mid_position.y, level) >= RiverContour.THRESHOLD
					if mid_inside == inside:
						low = middle
					else:
						high = middle
				closest = minf(closest, high)
				break
			previous = distance
	return closest
