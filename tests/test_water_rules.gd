extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_river()
	var rules := WaterRules.new(island)
	var unit: float = IslandDefinition.TILE_SIZE
	var zones: Array[int] = [0, 0, 0, 0]
	for z in range(island.depth * 6):
		for x in range(island.width * 6):
			var p := Vector3((float(x) + 0.5) * unit / 6.0, 0.0, (float(z) + 0.5) * unit / 6.0)
			var classification: Dictionary = rules.sample(p)
			zones[int(classification["zone"])] += 1
	for zone in range(zones.size()):
		if zones[zone] == 0:
			_fail("no positions classified as " + WaterRules.zone_name(zone))
			return
	var dry_start := Vector3(12.5 * unit, 0.0, 6.5 * unit)
	var deep_destination := Vector3(10.5 * unit, 0.0, 6.5 * unit)
	if rules.sample(dry_start)["water"]:
		_fail("dry start classified wet")
		return
	if rules.sample(deep_destination)["zone"] != WaterRules.Zone.DEEP:
		_fail("channel center should be classified deep")
		return
	if rules.can_traverse_path(dry_start, deep_destination, WaterRules.Mode.WALK):
		_fail("walking crossed a river")
		return
	if rules.can_traverse_path(dry_start, deep_destination, WaterRules.Mode.WADE):
		_fail("wading crossed an interior channel")
		return
	if not rules.can_traverse_path(dry_start, deep_destination, WaterRules.Mode.SWIM):
		_fail("swim mode could not cross flat river")
		return
	var island_narrow := IslandDefinition.new(5, 3)
	island_narrow.set_water(2, 1, true)
	var narrow_rules := WaterRules.new(island_narrow)
	if narrow_rules.can_traverse_path(Vector3(1.5 * unit, 0.0, 1.5 * unit), Vector3(3.5 * unit, 0.0, 1.5 * unit), WaterRules.Mode.WALK):
		_fail("long walking step tunneled through narrow water")
		return
	var high := Vector3(8.5 * unit, IslandDefinition.HEIGHT_STEP, 3.5 * unit)
	var low := Vector3(9.5 * unit, 0.0, 3.5 * unit)
	if rules.can_traverse_path(high, low, WaterRules.Mode.SWIM):
		_fail("swimming should not bypass a vertical cliff / waterfall")
		return
	print("PASS — worldspace zones %s, shore/wade/swim path rules, anti-tunnel and cliff gate" % [zones])
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
