class_name RiverCharacter
extends CharacterBody3D
## Real physics capsule + simple lab mannequin. Final Nusantara character art is separate.

const FOOT_OFFSET: float = 0.62
const GRAVITY: float = 16.0
const FLOAT_OFFSET: float = 0.18
const CURRENT_SPEED: float = 0.55

enum MotionState { IDLE, WALK, WADE, SWIM }

var island: IslandDefinition
var rules: WaterRules
var mode: WaterRules.Mode = WaterRules.Mode.WALK
var input_direction: Vector2 = Vector2.ZERO
var blocked: bool = false
var floating: bool = false
var water_depth: float = 0.0
var last_zone: WaterRules.Zone = WaterRules.Zone.LAND
var mesh_root: Node3D
var arm_joints: Array[Node3D] = []
var leg_joints: Array[Node3D] = []
var head_mesh: MeshInstance3D
var animation_bridge: MannequinAnimationBridge
var rig_visual: CharacterRigVisual
var skeleton_bridge: SkeletonAnimationBridge
var shovel_prop: ShovelTool
var impact_effects: DigImpactFX
var foot_probe: FootGroundProbe
var foot_ik: FootIKController
var shovel_impacted: bool = false
var use_skeleton_rig: bool = true
var ripple_effects: WaterRippleFX
var was_in_water: bool = false
var ripple_cooldown: float = 0.0
var motion_state: MotionState = MotionState.IDLE
var animation_phase: float = 0.0
var walk_blend: float = 0.0
var wade_blend: float = 0.0
var swim_blend: float = 0.0
var current_enabled: bool = true
var flow_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	name = "PhysicsCharacter"
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(65.0)
	safe_margin = 0.022
	collision_layer = 4
	# Terrain 1 + original props 16 + traversable connectors 32.
	collision_mask = 49
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = FOOT_OFFSET * 2.0
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollision"
	collider.shape = capsule
	add_child(collider)
	_create_model()
	animation_bridge = MannequinAnimationBridge.new()
	animation_bridge.name = "AnimationBridge"
	add_child(animation_bridge)
	animation_bridge.setup(self)
	rig_visual = CharacterRigVisual.new()
	rig_visual.name = "CharacterRigVisual"
	mesh_root.add_child(rig_visual)
	rig_visual.setup()
	skeleton_bridge = SkeletonAnimationBridge.new()
	skeleton_bridge.name = "SkeletonAnimationBridge"
	add_child(skeleton_bridge)
	skeleton_bridge.setup(self, rig_visual)
	shovel_prop = ShovelTool.new()
	shovel_prop.setup(rig_visual.skeleton, rig_visual.bones, self)
	impact_effects = DigImpactFX.new()
	impact_effects.name = "DigImpactFX"
	add_child(impact_effects)
	foot_probe = FootGroundProbe.new()
	add_child(foot_probe)
	foot_probe.setup(self, rig_visual)
	foot_ik = FootIKController.new()
	add_child(foot_ik)
	foot_ik.setup(self, rig_visual, foot_probe)
	update_rig_visibility()
	ripple_effects = WaterRippleFX.new()
	ripple_effects.name = "WaterContactFX"
	add_child(ripple_effects)


func configure(source: IslandDefinition, water_rules: WaterRules) -> void:
	island = source
	rules = water_rules


func set_input_direction(axis: Vector2) -> void:
	input_direction = axis.limit_length(1.0)


func set_start(x: float, z: float) -> void:
	var level: int = island.height_at(floori(x / IslandDefinition.TILE_SIZE), floori(z / IslandDefinition.TILE_SIZE))
	global_position = Vector3(x, RiverBathymetry.floor_height_at(island, x, z, level) + FOOT_OFFSET + 0.05, z)
	velocity = Vector3.ZERO
	was_in_water = false
	ripple_cooldown = 0.0


func feet_position() -> Vector3:
	return global_position - Vector3(0.0, FOOT_OFFSET, 0.0)


func _physics_process(delta: float) -> void:
	if rules == null or island == null:
		return
	var sample: Dictionary = rules.sample(feet_position())
	last_zone = sample["zone"]
	water_depth = sample["depth"]
	var speed: float = 2.7 if mode == WaterRules.Mode.WALK else (1.65 if mode == WaterRules.Mode.WADE else 1.90)
	var desired: Vector3 = Vector3(input_direction.x, 0.0, input_direction.y) * speed
	var inside_channel: bool = mode == WaterRules.Mode.SWIM and bool(sample["water"]) and water_depth >= 0.34
	flow_velocity = Vector2.ZERO
	if inside_channel and current_enabled:
		var natural_flow: Vector2 = sample["flow"]
		if natural_flow.length_squared() > 0.001:
			var trial: Vector3 = feet_position() + Vector3(natural_flow.x, 0.0, natural_flow.y) * CURRENT_SPEED * delta
			if bool(rules.sample(trial)["water"]):
				flow_velocity = natural_flow * CURRENT_SPEED
			desired += Vector3(flow_velocity.x, 0.0, flow_velocity.y)
	var candidate: Vector3 = feet_position() + desired * delta
	blocked = not rules.can_traverse_path(feet_position(), candidate, mode)
	if blocked:
		desired = Vector3.ZERO
	velocity.x = desired.x
	velocity.z = desired.z
	floating = inside_channel
	if floating:
		var target_center: float = float(sample["surface_y"]) + FLOAT_OFFSET
		velocity.y = clampf((target_center - global_position.y) * 7.0, -2.4, 2.4)
	else:
		velocity.y -= GRAVITY * delta
	var previous_position: Vector3 = global_position
	move_and_slide()
	# Physics sliding and ground separation may nudge the actor slightly into a
	# forbidden zone even when the requested horizontal segment was rejected.
	var after_motion: Dictionary = rules.sample(feet_position())
	if not WaterRules.can_enter(after_motion["zone"], mode):
		global_position = previous_position
		velocity.x = 0.0
		velocity.z = 0.0
		blocked = true
	else:
		last_zone = after_motion["zone"]
		water_depth = after_motion["depth"]
	_update_motion_state(delta, desired)
	_update_water_contact_fx(delta, after_motion)
	if rig_visual != null:
		rig_visual.set_waterline(water_depth, bool(after_motion["water"]), delta)
	_update_shovel_action()


func try_use_shovel() -> bool:
	if mode != WaterRules.Mode.WALK or floating or rules == null or not is_on_floor():
		return false
	var sample: Dictionary = rules.sample(feet_position())
	if sample["zone"] != WaterRules.Zone.LAND and sample["zone"] != WaterRules.Zone.BANK:
		return false
	if skeleton_bridge == null or not skeleton_bridge.fire_shovel():
		return false
	shovel_impacted = false
	if shovel_prop != null:
		shovel_prop.visible = use_skeleton_rig
	return true


func _update_shovel_action() -> void:
	if skeleton_bridge == null or shovel_prop == null:
		return
	var active: bool = skeleton_bridge.shovel_active()
	shovel_prop.visible = active and use_skeleton_rig
	if not active or shovel_impacted or skeleton_bridge.shovel_elapsed < 0.57:
		return
	shovel_impacted = true
	var forward := Vector3(-sin(mesh_root.rotation.y), 0.0, -cos(mesh_root.rotation.y))
	var center: Vector3 = feet_position() + forward * 0.72
	var origin: Vector3 = center + Vector3.UP * 1.2
	var destination: Vector3 = center - Vector3.UP * 2.4
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, destination, 1))
	if hit.is_empty():
		return
	var ground_point: Vector3 = hit["position"]
	var sample: Dictionary = rules.sample(ground_point)
	if sample["zone"] == WaterRules.Zone.LAND or sample["zone"] == WaterRules.Zone.BANK:
		impact_effects.stamp_at(ground_point)


func update_rig_visibility() -> void:
	if mesh_root == null or rig_visual == null:
		return
	for part in mesh_root.get_children():
		if part is Node3D and part != rig_visual:
			(part as Node3D).visible = not use_skeleton_rig
	rig_visual.visible = use_skeleton_rig


func _update_water_contact_fx(delta: float, sample: Dictionary) -> void:
	if ripple_effects == null:
		return
	var wet: bool = bool(sample["water"])
	ripple_cooldown = maxf(0.0, ripple_cooldown - delta)
	if not wet:
		was_in_water = false
		return
	var surface: Vector3 = Vector3(global_position.x, float(sample["surface_y"]), global_position.z)
	if not was_in_water:
		ripple_effects.emit_at(surface, 1.35)
		ripple_cooldown = 0.18
	elif Vector2(velocity.x, velocity.z).length() > 0.15 and ripple_cooldown <= 0.0:
		ripple_effects.emit_at(surface, 0.83 if floating else 0.72)
		ripple_cooldown = 0.24
	was_in_water = true


func _update_motion_state(delta: float, horizontal_velocity: Vector3) -> void:
	if floating:
		motion_state = MotionState.SWIM
	elif mode == WaterRules.Mode.WADE and last_zone == WaterRules.Zone.SHALLOW:
		motion_state = MotionState.WADE
	elif input_direction.length_squared() > 0.001 and not blocked:
		motion_state = MotionState.WALK
	else:
		motion_state = MotionState.IDLE
	var weight: float = minf(1.0, delta * 6.0)
	walk_blend = lerpf(walk_blend, 1.0 if motion_state == MotionState.WALK else 0.0, weight)
	wade_blend = lerpf(wade_blend, 1.0 if motion_state == MotionState.WADE else 0.0, weight)
	swim_blend = lerpf(swim_blend, 1.0 if motion_state == MotionState.SWIM else 0.0, weight)
	var cycle_rate: float = 6.5 * walk_blend + 3.5 * wade_blend + 4.7 * swim_blend
	animation_phase += cycle_rate * delta
	if mesh_root == null:
		return
	mesh_root.rotation.x = lerpf(mesh_root.rotation.x, -0.54 * swim_blend, weight)
	mesh_root.rotation.z = 0.03 * sin(animation_phase) * (walk_blend + wade_blend)
	if horizontal_velocity.length_squared() > 0.001 and not blocked:
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, atan2(-horizontal_velocity.x, -horizontal_velocity.z), minf(1.0, delta * 8.0))
	if skeleton_bridge != null and skeleton_bridge.initialized:
		skeleton_bridge.travel(state_name(motion_state))
	if animation_bridge != null and animation_bridge.initialized:
		animation_bridge.travel(state_name(motion_state))
		return
	for i in range(2):
		var offset: float = float(i) * PI
		arm_joints[i].rotation.x = sin(animation_phase + offset) * (0.47 * walk_blend + 0.30 * wade_blend) + sin(animation_phase * 1.17 + offset) * 0.78 * swim_blend
		arm_joints[i].rotation.z = (-1.0 if i == 0 else 1.0) * (0.12 * wade_blend + 0.37 * swim_blend)
		leg_joints[i].rotation.x = sin(animation_phase + offset + PI) * (0.52 * walk_blend + 0.22 * wade_blend) + sin(animation_phase * 1.17 + offset + PI) * 0.46 * swim_blend
	if head_mesh != null:
		head_mesh.position.y = 0.32 + 0.018 * sin(animation_phase * 2.0) * (walk_blend + swim_blend)


static func state_name(state: MotionState) -> String:
	match state:
		MotionState.IDLE:
			return "DIAM"
		MotionState.WALK:
			return "JALAN"
		MotionState.WADE:
			return "RENDAM"
		MotionState.SWIM:
			return "RENANG"
	return "?"


func _create_model() -> void:
	# A deliberately small humanoid physics proxy, not the art asset / final rig.
	mesh_root = Node3D.new()
	mesh_root.name = "LabMannequin"
	add_child(mesh_root)
	var body := CapsuleMesh.new()
	body.radius = 0.19
	body.height = 0.57
	_add_part("Torso", body, Vector3(0.0, -0.14, 0.0), Color(0.19, 0.40, 0.61))
	var head := SphereMesh.new()
	head.radius = 0.255
	head.height = 0.47
	head_mesh = _add_part("Head", head, Vector3(0.0, 0.32, -0.006), Color(0.92, 0.72, 0.53))
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.075
		arm.height = 0.36
		arm_joints.append(_add_joint("ArmPivot", arm, Vector3(side * 0.22, 0.015, 0.0), Vector3(0.0, -0.14, 0.0), Color(0.22, 0.43, 0.63)))
		var leg := CapsuleMesh.new()
		leg.radius = 0.086
		leg.height = 0.32
		leg_joints.append(_add_joint("LegPivot", leg, Vector3(side * 0.115, -0.28, 0.02), Vector3(0.0, -0.145, 0.0), Color(0.36, 0.28, 0.25)))
		var eye := SphereMesh.new()
		eye.radius = 0.027
		eye.height = 0.05
		_add_part("Eye", eye, Vector3(side * 0.075, 0.35, -0.235), Color(0.10, 0.13, 0.16))


func _add_part(part_name: String, shape: Mesh, offset: Vector3, tint: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = part_name
	item.mesh = shape
	item.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.8
	item.material_override = mat
	mesh_root.add_child(item)
	return item


func _add_joint(part_name: String, shape: Mesh, anchor: Vector3, offset: Vector3, tint: Color) -> Node3D:
	var joint := Node3D.new()
	joint.name = part_name
	joint.position = anchor
	mesh_root.add_child(joint)
	var part: MeshInstance3D = _add_part(part_name + "Mesh", shape, offset, tint)
	mesh_root.remove_child(part)
	joint.add_child(part)
	return joint
