extends SceneTree
## Engine regression for immutable-at-revision texture cache identities.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.new(4, 4)
	island.set_land(1, 1, false)
	var revision: int = island.coastline_revision
	var a: ImageTexture = CoastBuilder.make_signed_coast_texture(island)
	var profile_a: ImageTexture = CoastBuilder.make_shoreline_texture(island)
	if a != CoastBuilder.make_signed_coast_texture(island) or profile_a != CoastBuilder.make_shoreline_texture(island):
		_fail("unchanged terrain rebuilt the expensive coast texture")
		return
	island.set_height(0, 0, 0)
	island.set_water(0, 0, false)
	island.set_land(1, 1, false)
	island.set_coast_inset(0, 1, 0.0)
	if island.coastline_revision != revision:
		_fail("no-op mutations advanced revision")
		return
	island.set_coast_inset(0, 1, 0.5)
	if island.coastline_revision <= revision:
		_fail("real sculpt did not invalidate SDF")
		return
	var b: ImageTexture = CoastBuilder.make_signed_coast_texture(island)
	var profile_b: ImageTexture = CoastBuilder.make_shoreline_texture(island)
	if a == b or profile_a == profile_b:
		_fail("modified coastline kept stale cached texture")
		return
	if b != CoastBuilder.make_signed_coast_texture(island):
		_fail("new texture was not cached")
		return
	print("PASS — shoreline/SDF cache reuse, no-op revision and sculpt invalidation")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
