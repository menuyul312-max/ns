extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var island := IslandDefinition.fixture_terraces()
	var world := TerrainBuilder.build_world(island)
	root.add_child(world)
	var walker := CharacterBody3D.new()
	walker.name = "CollisionProbe"
	walker.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	walker.safe_margin = 0.025
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.06
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	walker.add_child(collision)
	walker.position = Vector3(2.5 * IslandDefinition.TILE_SIZE, 0.55, 0.5 * IslandDefinition.TILE_SIZE)
	root.add_child(walker)
	await physics_frame
	var contacted_wall: bool = false
	for frame in range(100):
		walker.velocity = Vector3(0.0, 0.0, 2.7)
		walker.move_and_slide()
		contacted_wall = contacted_wall or walker.get_slide_collision_count() > 0
		await physics_frame
	if not contacted_wall:
		push_error("FAIL — character probe never made contact with cliff")
		quit(1)
		return
	if walker.position.z > IslandDefinition.TILE_SIZE:
		push_error("FAIL — character probe moved through cliff: z=" + str(walker.position.z))
		quit(1)
		return
	print("PASS — capsule probe walked toward cliff, collided, and stayed below the ledge")
	quit(0)
