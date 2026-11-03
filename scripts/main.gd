extends Node3D

var island: IslandDefinition
var composer: IslandComposer
var terrain_root: Node3D
var water_root: Node3D
var ocean_root: Node3D
var link_root: Node3D
var reference_camera: Camera3D
var status_label: Label
var water_rules: WaterRules
var water_audit: Dictionary = {}
var access_audit: Dictionary = {}
var coast_audit: Dictionary = {}
var zone_overlay: Node3D
var current_overlay: Node3D
var access_overlay: Node3D
var show_zone_overlay: bool = false
var show_access_overlay: bool = false
var enable_current: bool = true
var traversal_probe: Node3D
var probe_material: StandardMaterial3D
var probe_mode: WaterRules.Mode = WaterRules.Mode.WALK
var show_probe: bool = true
var probe_blocked: bool = false
var physics_actor: RiverCharacter
var use_physics_actor: bool = true
var manual_actor_control: bool = false
var coast_sculpt_mode: bool = false
var land_mask_edit_mode: bool = false
var land_mask_brush_radius: int = 0
var show_re_ground_probe: bool = false
var rejected_tile_marker: MeshInstance3D
const SAVE_PATH: String = "user://nusantara_island_layout.json"


func _ready() -> void:
	composer = IslandComposer.new(IslandDefinition.fixture_river())
	_refresh_terrain()
	_create_lighting()
	_create_camera()
	_create_hud()
	_create_probe()
	_create_physics_actor()
	_update_status()
	# The reference render focuses on cliff silhouette, without placeholder markers.
	print("World Lab ready: %sx%s, %s exposed cliff edges" % [island.width, island.depth, island.cliff_edge_count()])


func _refresh_terrain() -> void:
	if terrain_root != null:
		remove_child(terrain_root)
		terrain_root.queue_free()
	if water_root != null:
		remove_child(water_root)
		water_root.queue_free()
	if link_root != null:
		remove_child(link_root)
		link_root.queue_free()
	if ocean_root != null:
		remove_child(ocean_root)
		ocean_root.queue_free()
	island = composer.island
	water_rules = WaterRules.new(island)
	water_audit = IslandWaterValidator.audit(island)
	access_audit = IslandAccessAudit.analyze(island)
	coast_audit = IslandCoastLoops.trace(island)
	terrain_root = TerrainBuilder.build_world(island)
	add_child(terrain_root)
	water_root = WaterBuilder.build_world(island)
	add_child(water_root)
	ocean_root = CoastBuilder.build_world(island)
	add_child(ocean_root)
	link_root = IslandLinkBuilder.build_world(island)
	add_child(link_root)
	_refresh_zone_overlay()
	_refresh_access_overlay()
	if rejected_tile_marker != null and rejected_tile_marker.visible:
		rejected_tile_marker.visible = false
	if traversal_probe != null:
		var tile := Vector2i(floori(traversal_probe.position.x / IslandDefinition.TILE_SIZE), floori(traversal_probe.position.z / IslandDefinition.TILE_SIZE))
		if not island.is_land(tile.x, tile.y):
			_reset_probe_position()
		_snap_probe_height()
	if physics_actor != null:
		var p: Vector3 = physics_actor.global_position
		physics_actor.configure(island, water_rules)
		if not island.is_land(floori(p.x / IslandDefinition.TILE_SIZE), floori(p.z / IslandDefinition.TILE_SIZE)):
			p = traversal_probe.position
		physics_actor.set_start(p.x, p.z)
	_reframe_camera()
	_update_status()


func _refresh_zone_overlay() -> void:
	if zone_overlay != null:
		remove_child(zone_overlay)
		zone_overlay.queue_free()
		zone_overlay = null
	if current_overlay != null:
		remove_child(current_overlay)
		current_overlay.queue_free()
		current_overlay = null
	if show_zone_overlay:
		zone_overlay = WaterZoneOverlay.build(island)
		add_child(zone_overlay)
		current_overlay = WaterFlowOverlay.build(island)
		add_child(current_overlay)


func _refresh_access_overlay() -> void:
	if access_overlay != null:
		remove_child(access_overlay)
		access_overlay.queue_free()
		access_overlay = null
	if show_access_overlay:
		access_overlay = IslandAccessOverlay.build(island, access_audit)
		add_child(access_overlay)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				if composer.use_fixture(event.keycode - KEY_0):
					_refresh_terrain()
			KEY_S:
				if event.ctrl_pressed:
					print("Layout saved: ", composer.save_layout(SAVE_PATH))
			KEY_L:
				if composer.load_layout(SAVE_PATH):
					_refresh_terrain()
			KEY_V:
				show_zone_overlay = not show_zone_overlay
				_refresh_zone_overlay()
				_update_status()
			KEY_B:
				composer.strict_build_rules = not composer.strict_build_rules
				composer.last_edit_report = {"allowed": true, "code": "MODE", "message": "Pemeriksaan 3x3 aktif" if composer.strict_build_rules else "Pemeriksaan dimatikan"}
				if rejected_tile_marker != null:
					rejected_tile_marker.visible = false
				_update_status()
			KEY_N:
				show_access_overlay = not show_access_overlay
				_refresh_access_overlay()
				_update_status()
			KEY_O:
				coast_sculpt_mode = not coast_sculpt_mode
				if coast_sculpt_mode:
					land_mask_edit_mode = false
				_update_status()
			KEY_T:
				land_mask_edit_mode = not land_mask_edit_mode
				if land_mask_edit_mode:
					coast_sculpt_mode = false
				_update_status()
			KEY_U:
				land_mask_brush_radius = 1 - land_mask_brush_radius
				composer.last_edit_report = {"allowed": true, "code": "BRUSH", "message": "Edit topologi %s" % ("3×3" if land_mask_brush_radius == 1 else "1×1")}
				_update_status()
			KEY_Y:
				show_re_ground_probe = not show_re_ground_probe
				_update_status()
			KEY_K:
				composer.protect_connectivity = not composer.protect_connectivity
				composer.last_edit_report = {"allowed": true, "code": "MODE", "message": "Perlindungan jalur ON" if composer.protect_connectivity else "Perlindungan jalur OFF"}
				if rejected_tile_marker != null:
					rejected_tile_marker.visible = false
				_update_status()
			KEY_F:
				enable_current = not enable_current
				if physics_actor != null:
					physics_actor.current_enabled = enable_current
				_update_status()
			KEY_M:
				probe_mode = (probe_mode + 1) % 3 as WaterRules.Mode
				if physics_actor != null:
					physics_actor.mode = probe_mode
				probe_blocked = false
				_update_probe_appearance()
				_update_status()
			KEY_P:
				show_probe = not show_probe
				if traversal_probe != null:
					traversal_probe.visible = show_probe and not use_physics_actor
				_update_status()
			KEY_C:
				use_physics_actor = not use_physics_actor
				if traversal_probe != null:
					traversal_probe.visible = show_probe and not use_physics_actor
				if physics_actor != null:
					physics_actor.visible = use_physics_actor
					physics_actor.set_input_direction(Vector2.ZERO)
				_update_status()
			KEY_R:
				if physics_actor != null:
					physics_actor.use_skeleton_rig = not physics_actor.use_skeleton_rig
					physics_actor.update_rig_visibility()
				_update_status()
			KEY_E:
				if use_physics_actor and physics_actor != null:
					physics_actor.try_use_shovel()
				_update_status()
			KEY_G:
				if physics_actor != null and physics_actor.foot_probe != null:
					physics_actor.foot_probe.show_debug = not physics_actor.foot_probe.show_debug
				_update_status()
			KEY_I:
				if physics_actor != null and physics_actor.foot_ik != null:
					physics_actor.foot_ik.set_ik_enabled(not physics_actor.foot_ik.enabled_by_player)
				_update_status()
	if event is InputEventMouseButton and event.pressed:
		if land_mask_edit_mode and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_edit_land_mask_at_screen(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
			return
		if coast_sculpt_mode and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_sculpt_coast_at_screen(event.position, 0.20 if event.button_index == MOUSE_BUTTON_LEFT else -0.20)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.alt_pressed:
				_edit_at_screen(event.position, 1, false, 0, "variation" if event.shift_pressed else "unit")
			elif event.ctrl_pressed:
				_edit_at_screen(event.position, 1, false, 1, "variation" if event.shift_pressed else "unit")
			else:
				_edit_at_screen(event.position, 1, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.shift_pressed and event.ctrl_pressed and not event.alt_pressed:
				_edit_at_screen(event.position, 0, false, -3)
			elif event.shift_pressed and not event.alt_pressed and not event.ctrl_pressed:
				_edit_at_screen(event.position, 0, false, -2)
			elif event.alt_pressed or event.ctrl_pressed:
				_edit_at_screen(event.position, -1, false, 0 if event.alt_pressed else 1, "rotation")
			else:
				_edit_at_screen(event.position, -1)


func _process(delta: float) -> void:
	if water_rules == null:
		return
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if use_physics_actor and physics_actor != null:
		if not manual_actor_control:
			physics_actor.set_input_direction(input.normalized())
		_update_status()
		return
	if not show_probe or traversal_probe == null:
		return
	if input.length_squared() <= 0.001:
		return
	var speed: float = 2.6 if probe_mode == WaterRules.Mode.WALK else (1.6 if probe_mode == WaterRules.Mode.WADE else 1.9)
	var unit: Vector2 = input.normalized()
	var destination: Vector3 = traversal_probe.position + Vector3(unit.x, 0.0, unit.y) * speed * delta
	var permitted: bool = water_rules.can_traverse_path(traversal_probe.position, destination, probe_mode)
	probe_blocked = not permitted
	if permitted:
		traversal_probe.position = destination
		_snap_probe_height()
	_update_probe_appearance()
	_update_status()


func _edit_at_screen(screen_position: Vector2, difference: int, toggle_river: bool = false, edit_layer: int = -1, layer_field: String = "") -> void:
	if reference_camera == null:
		return
	var origin: Vector3 = reference_camera.project_ray_origin(screen_position)
	var destination: Vector3 = origin + reference_camera.project_ray_normal(screen_position) * 100.0
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, destination, 1))
	var point: Vector3 = hit["position"] if not hit.is_empty() else Vector3.ZERO
	var found: bool = not hit.is_empty()
	if (toggle_river or edit_layer == -3) and water_rules != null:
		# The bed lies below the visible water. Pick the first water surface along
		# the ray, or the same click could edit the tile behind the river.
		var ray_direction: Vector3 = (destination - origin).normalized()
		if absf(ray_direction.y) > 0.0001:
			var closest: float = origin.distance_to(point) if found else 100.0
			for level in water_rules.contour.wet_levels():
				var water_y: float = float(level) * IslandDefinition.HEIGHT_STEP + WaterBuilder.WATER_ABOVE_GROUND
				var distance: float = (water_y - origin.y) / ray_direction.y
				if distance < 0.0 or distance > closest + 0.025:
					continue
				var on_surface: Vector3 = origin + ray_direction * distance
				if RiverContour.field_at(island, on_surface.x, on_surface.z, level) >= RiverContour.THRESHOLD:
					closest = distance
					point = on_surface
					found = true
	if not found:
		return
	var x: int = floori(point.x / IslandDefinition.TILE_SIZE)
	var z: int = floori(point.z / IslandDefinition.TILE_SIZE)
	var changed: bool = false
	if edit_layer == -3:
		changed = composer.cycle_connector(x, z)
	elif edit_layer == -2:
		changed = composer.cycle_occupant(x, z)
	elif edit_layer >= 0:
		changed = composer.cycle_terrain_layer(x, z, edit_layer, layer_field)
	else:
		changed = composer.toggle_water(x, z) if toggle_river else composer.modify_tile(x, z, difference)
	if changed:
		_refresh_terrain()
	elif not bool(composer.last_edit_report.get("allowed", true)):
		_show_rejected_tile(x, z)
		_update_status()


func _sculpt_coast_at_screen(screen_position: Vector2, difference: float) -> void:
	if reference_camera == null or island == null:
		return
	var origin: Vector3 = reference_camera.project_ray_origin(screen_position)
	var end: Vector3 = origin + reference_camera.project_ray_normal(screen_position) * 100.0
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1))
	if hit.is_empty():
		return
	var p: Vector3 = hit["position"]
	var w: float = float(island.width) * IslandDefinition.TILE_SIZE
	var d: float = float(island.depth) * IslandDefinition.TILE_SIZE
	var gaps: Array[float] = [p.x, w - p.x, p.z, d - p.z]
	var side: int = gaps.find(gaps.min())
	if gaps[side] > IslandDefinition.TILE_SIZE * 1.45:
		composer.last_edit_report = {"allowed": false, "code": "COAST_DISTANCE", "message": "Pilih daratan dekat bibir pulau"}
		_update_status()
		return
	var along: float = p.z if side < 2 else p.x
	var slot: int = roundi(along / IslandDefinition.TILE_SIZE)
	if composer.sculpt_coast(side, slot, difference):
		_refresh_terrain()
	else:
		_update_status()


func _edit_land_mask_at_screen(screen_position: Vector2, make_land: bool) -> void:
	# Cast against a *fixed sea-level plane*. Raycasting only real ground could
	# never refill a previously erased tile because its collider is gone.
	if reference_camera == null:
		return
	var origin: Vector3 = reference_camera.project_ray_origin(screen_position)
	var direction: Vector3 = reference_camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return
	var along_ray: float = -origin.y / direction.y
	if along_ray < 0.0:
		return
	var sample: Vector3 = origin + direction * along_ray
	var x: int = floori(sample.x / IslandDefinition.TILE_SIZE)
	var z: int = floori(sample.z / IslandDefinition.TILE_SIZE)
	if composer.set_land_area(x, z, make_land, land_mask_brush_radius):
		_refresh_terrain()
	else:
		_update_status()


func _show_rejected_tile(x: int, z: int) -> void:
	if not island.contains(x, z):
		return
	if rejected_tile_marker == null:
		rejected_tile_marker = MeshInstance3D.new()
		rejected_tile_marker.name = "RejectedEditMarker"
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(IslandDefinition.TILE_SIZE * 0.93, 0.07, IslandDefinition.TILE_SIZE * 0.93)
		rejected_tile_marker.mesh = tile_mesh
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(1.0, 0.10, 0.12, 0.88)
		red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red.no_depth_test = true
		rejected_tile_marker.material_override = red
		add_child(rejected_tile_marker)
	var px: float = (float(x) + 0.5) * IslandDefinition.TILE_SIZE
	var pz: float = (float(z) + 0.5) * IslandDefinition.TILE_SIZE
	rejected_tile_marker.position = Vector3(px, float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP + 0.11, pz)
	rejected_tile_marker.visible = true


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EditorHelp"
	var backdrop := Panel.new()
	backdrop.name = "HUDBackdrop"
	backdrop.position = Vector2(10, 10)
	backdrop.size = Vector2(750, 375)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.16, 0.21, 0.79)
	panel_style.corner_radius_top_left = 11
	panel_style.corner_radius_top_right = 11
	panel_style.corner_radius_bottom_left = 11
	panel_style.corner_radius_bottom_right = 11
	backdrop.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(backdrop)
	var label := Label.new()
	label.position = Vector2(22, 18)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.96, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.07, 0.09, 0.30))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(label)
	add_child(canvas)
	status_label = label
	_update_status()


func _update_status() -> void:
	if status_label != null and island != null:
		var audit_info: String = "Jaringan air %s | waterfall %s" % [water_audit.get("components", 0), water_audit.get("waterfalls", 0)]
		var notices: Array = water_audit.get("notices", [])
		if not notices.is_empty():
			audit_info += " | Cek: " + str(notices[0])
		var probe_info: String = "Probe: mati"
		var locomotion_info: String = audit_info
		var rig_info: String = "[R] tampilan rig: tidak tersedia"
		if use_physics_actor and physics_actor != null:
			var physics_sample: Dictionary = water_rules.sample(physics_actor.feet_position())
			probe_info = "AKTOR: %s | %s | dalam %.2fm | %s%s" % [WaterRules.mode_name(probe_mode), physics_sample["label"], physics_sample["depth"], "MENGAPUNG" if physics_actor.floating else "GRAVITASI", " | TERTAHAN" if physics_actor.blocked else ""]
			var action_info: String = "SEKOP" if physics_actor.skeleton_bridge.shovel_active() else "SIAP"
			locomotion_info = "ANIM: %s | aksi %s | bekas gali %s" % [physics_actor.skeleton_bridge.current_clip.to_upper(), action_info, physics_actor.impact_effects.emitted_total]
			rig_info = "[E] sekop  [R] %s  [G] target %s  [I] IK %s" % ["GLB" if physics_actor.use_skeleton_rig and physics_actor.rig_visual.imported_glb else ("rig debug" if physics_actor.use_skeleton_rig else "manekin lama"), "ON" if physics_actor.foot_probe.show_debug else "OFF", "ON" if physics_actor.foot_ik.enabled_by_player else "OFF"]
		elif show_probe and traversal_probe != null and water_rules != null:
			var p: Vector3 = traversal_probe.position
			var sample: Dictionary = water_rules.sample(p)
			probe_info = "Probe: %s | %s | jarak tepi %.2fm%s" % [WaterRules.mode_name(probe_mode), sample["label"], sample["shore_distance"], " | TERTAHAN" if probe_blocked else ""]
		var rule_line: String = "[B] validasi 3x3: %s  |  Shift+klik kanan: kosong → pohon → rumah" % ("ON" if composer.strict_build_rules else "OFF")
		var access_line: String = "[N] peta akses %s  |  [K] lindungi jalur %s  |  %s region jalan" % ["ON" if show_access_overlay else "OFF", "ON" if composer.protect_connectivity else "OFF", access_audit.get("count", 0)]
		var ground_line: String = "[Y] probe 4 titik RE: OFF"
		if show_re_ground_probe:
			var probe_position: Vector3 = traversal_probe.position if traversal_probe != null else Vector3.ZERO
			if use_physics_actor and physics_actor != null:
				probe_position = physics_actor.feet_position()
			var gx: int = floori(probe_position.x / IslandDefinition.TILE_SIZE)
			var gz: int = floori(probe_position.z / IslandDefinition.TILE_SIZE)
			var ground: Dictionary = NusantaraGroundQuery.sample_tile(island, gx, gz)
			ground_line = "[Y] 4 arah N/W/S/E | air=%s | no-entry=%s | allWet=%s" % [ground["water_flags"], ground["no_entry_flags"], ground["all_water"]]
		var result_line: String = "EDIT: %s — %s" % [str(composer.last_edit_report.get("code", "READY")), str(composer.last_edit_report.get("message", ""))]
		result_line += " | Kontur %s pulau / %s cekungan" % [coast_audit.get("islands", 0), coast_audit.get("holes", 0)]
		var link_count: int = island.connectors.size() - island.connectors.count(0)
		status_label.text = "NUSANTARA • WORLD LAB 46 / COAST RING STUDY\nDenah %s×%s | darat %s | air %s | terjun %s | konektor %s\nKlik kiri: naik  | kanan: turun  | Shift+kiri: sungai\nAlt+kiri: tanah  | Ctrl+kiri: dekor (layer 2)\n[T] edit topologi %s: kiri → LAUT, kanan → DARAT | [U] brush %s\n[O] ukir bibir luar %s: kiri → teluk, kanan → pulihkan\n%s\n%s\n%s\n%s\n[WASD] gerak   [Ctrl+S] simpan   [L] muat   [1]–[4] denah\n[V] zona %s   [C] aktor %s   [F] arus %s   [M] mode\n%s\n%s\n%s" % [island.width, island.depth, island.land_mask.count(1), island.water.count(1), island.waterfall_edge_count(), link_count, "ON" if land_mask_edit_mode else "OFF", "3×3" if land_mask_brush_radius == 1 else "1×1", "ON" if coast_sculpt_mode else "OFF", rule_line, access_line, ground_line, result_line, "ON" if show_zone_overlay else "OFF", "ON" if use_physics_actor else "OFF", "ON" if enable_current else "OFF", probe_info, locomotion_info, rig_info]


func _create_physics_actor() -> void:
	var actor := RiverCharacter.new()
	actor.configure(island, water_rules)
	actor.mode = probe_mode
	actor.current_enabled = enable_current
	add_child(actor)
	physics_actor = actor
	var p: Vector3 = traversal_probe.position
	actor.set_start(p.x, p.z)
	actor.visible = use_physics_actor
	traversal_probe.visible = show_probe and not use_physics_actor


func _create_probe() -> void:
	var node := Node3D.new()
	node.name = "TraversalProbe"
	add_child(node)
	traversal_probe = node
	probe_material = StandardMaterial3D.new()
	probe_material.albedo_color = Color(0.98, 0.72, 0.20)
	probe_material.roughness = 0.48
	var base := CylinderMesh.new()
	base.top_radius = 0.28
	base.bottom_radius = 0.28
	base.height = 0.07
	var foot := MeshInstance3D.new()
	foot.mesh = base
	foot.material_override = probe_material
	foot.position.y = 0.09
	node.add_child(foot)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.065
	mast.bottom_radius = 0.095
	mast.height = 0.50
	var pole := MeshInstance3D.new()
	pole.mesh = mast
	pole.material_override = probe_material
	pole.position.y = 0.38
	node.add_child(pole)
	var beacon := SphereMesh.new()
	beacon.radius = 0.17
	beacon.height = 0.32
	var head := MeshInstance3D.new()
	head.mesh = beacon
	head.material_override = probe_material
	head.position.y = 0.72
	node.add_child(head)
	_reset_probe_position()
	_snap_probe_height()
	_update_probe_appearance()


func _reset_probe_position() -> void:
	if traversal_probe == null:
		return
	var x: float = minf(float(island.width) - 0.45, 12.15) * IslandDefinition.TILE_SIZE
	var z: float = minf(float(island.depth) - 0.45, 6.45) * IslandDefinition.TILE_SIZE
	if not island.is_land(floori(x / IslandDefinition.TILE_SIZE), floori(z / IslandDefinition.TILE_SIZE)):
		var best: float = INF
		for gz in range(island.depth):
			for gx in range(island.width):
				if not island.is_land(gx, gz) or island.is_water(gx, gz):
					continue
				var px: float = (float(gx) + 0.5) * IslandDefinition.TILE_SIZE
				var pz: float = (float(gz) + 0.5) * IslandDefinition.TILE_SIZE
				var cost: float = Vector2(px - x, pz - z).length_squared()
				if cost < best:
					best = cost
					x = px
					z = pz
	traversal_probe.position = Vector3(x, 0.0, z)


func _snap_probe_height() -> void:
	if traversal_probe == null or water_rules == null:
		return
	var p: Vector3 = traversal_probe.position
	var x: int = floori(p.x / IslandDefinition.TILE_SIZE)
	var z: int = floori(p.z / IslandDefinition.TILE_SIZE)
	if not island.contains(x, z):
		return
	var level_y: float = float(island.height_at(x, z)) * IslandDefinition.HEIGHT_STEP
	var zone: WaterRules.Zone = water_rules.sample(Vector3(p.x, level_y, p.z))["zone"]
	traversal_probe.position.y = level_y + (0.17 if zone == WaterRules.Zone.SHALLOW else (0.24 if zone == WaterRules.Zone.DEEP else 0.10))


func _update_probe_appearance() -> void:
	if probe_material == null:
		return
	if probe_blocked:
		probe_material.albedo_color = Color(1.0, 0.23, 0.23)
	elif probe_mode == WaterRules.Mode.SWIM:
		probe_material.albedo_color = Color(0.13, 0.90, 0.97)
	elif probe_mode == WaterRules.Mode.WADE:
		probe_material.albedo_color = Color(0.98, 0.78, 0.23)
	else:
		probe_material.albedo_color = Color(0.95, 0.46, 0.18)


func _create_lighting() -> void:
	var env := WorldEnvironment.new()
	var world_env := Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color(0.72, 0.82, 0.89)
	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.89, 0.91, 1.0)
	world_env.ambient_light_energy = 0.48
	world_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = world_env
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 0.99
	sun.shadow_enabled = true
	add_child(sun)


func _create_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "ReferenceCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(27.0, 24.0, 27.0)
	add_child(camera)
	camera.current = true
	reference_camera = camera
	_reframe_camera()


func _reframe_camera() -> void:
	if reference_camera == null or island == null:
		return
	var span: float = float(maxi(island.width, island.depth)) * IslandDefinition.TILE_SIZE
	var focus := Vector3(float(island.width) * IslandDefinition.TILE_SIZE * 0.5, 1.15, float(island.depth) * IslandDefinition.TILE_SIZE * 0.5)
	reference_camera.size = maxf(27.0, span * 1.15)
	reference_camera.position = focus + Vector3(17.0, 23.0, 17.0)
	reference_camera.look_at(focus, Vector3.UP)


func _create_context_props() -> void:
	# Original, low-contrast markers help judge height/scale; no ACNH assets.
	for at in [Vector3(2.8, 1.55, 3.5), Vector3(13.0, 1.55, 11.8)]:
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.08
		trunk.bottom_radius = 0.12
		trunk.height = 0.8
		var marker := MeshInstance3D.new()
		marker.mesh = trunk
		marker.position = at + Vector3(0, 0.4, 0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.47, 0.35, 0.22)
		marker.material_override = material
		add_child(marker)
