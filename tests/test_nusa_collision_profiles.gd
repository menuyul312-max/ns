extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var humanoid: Dictionary = NusaCollisionProfile.load_profile()
	var winged: Dictionary = NusaCollisionProfile.load_profile("res://data/characters/collisions/winged_spirit.json")
	var quadruped: Dictionary = NusaCollisionProfile.load_profile("res://data/characters/collisions/quadruped.json")
	if humanoid.is_empty() or winged.is_empty() or quadruped.is_empty():
		_fail("collision profiles not loaded or validated")
		return
	if float(winged["radius"]) <= float(humanoid["radius"]) or float(quadruped["radius"]) <= float(winged["radius"]):
		_fail("archetype body sizes not independent")
		return
	var actor := RiverCharacter.new()
	actor.collision_profile_path = "res://data/characters/collisions/winged_spirit.json"
	root.add_child(actor)
	if actor.body_collision == null or actor.interaction_reach == null:
		_fail("missing movement capsule or independent interaction sensor")
		return
	var capsule: CapsuleShape3D = actor.body_collision.shape as CapsuleShape3D
	if capsule == null or absf(capsule.radius - float(winged["radius"])) > 0.00001:
		_fail("winged radius not applied")
		return
	if actor.interaction_reach.collision_layer != 0 or actor.interaction_reach.collision_mask != 16:
		_fail("interaction sensor must not physically block movement")
		return
	if not actor.interaction_reach.get_node("ReachVolume").shape is SphereShape3D:
		_fail("interaction sensor must use distinct sphere shape")
		return
	if absf(actor.feet_position().y - (actor.global_position.y - actor.body_foot_offset)) > 0.0001:
		_fail("collision foot reference not based on selected profile")
		return
	var invalid: Dictionary = humanoid.duplicate(true)
	invalid["height"] = 0.01
	if NusaCollisionProfile.validate(invalid).is_empty():
		_fail("invalid capsule shape accepted")
		return
	print("PASS — Nusa collisions v2: validated archetypes, gameplay capsule, independent rotated interaction sensor")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
