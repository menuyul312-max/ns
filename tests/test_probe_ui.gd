extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	if scene.traversal_probe == null or scene.water_rules == null:
		_fail("main scene missing traversal probe")
		return
	var v := InputEventKey.new()
	v.keycode = KEY_V
	v.pressed = true
	scene._input(v)
	if not scene.show_zone_overlay or scene.zone_overlay == null or scene.zone_overlay.get_node_or_null("WaterDepthZones") == null:
		_fail("zone overlay toggle did not build heatmap")
		return
	if scene.current_overlay == null or scene.current_overlay.get_node_or_null("FlowArrows") == null:
		_fail("zone toggle did not also build flow direction arrows")
		return
	var f := InputEventKey.new()
	f.keycode = KEY_F
	f.pressed = true
	scene._input(f)
	if scene.enable_current or scene.physics_actor.current_enabled:
		_fail("flow toggle did not disable actor drift")
		return
	var m := InputEventKey.new()
	m.keycode = KEY_M
	m.pressed = true
	scene._input(m)
	if scene.probe_mode != WaterRules.Mode.WADE:
		_fail("probe mode did not advance to wade")
		return
	var p := InputEventKey.new()
	p.keycode = KEY_P
	p.pressed = true
	scene._input(p)
	if scene.show_probe or scene.traversal_probe.visible:
		_fail("probe visibility toggle failed")
		return
	var rig_toggle := InputEventKey.new()
	rig_toggle.keycode = KEY_R
	rig_toggle.pressed = true
	scene._input(rig_toggle)
	if scene.physics_actor.use_skeleton_rig or scene.physics_actor.rig_visual.visible:
		_fail("R did not switch from GLB to mannequin")
		return
	scene._input(rig_toggle)
	if not scene.physics_actor.use_skeleton_rig or not scene.physics_actor.rig_visual.visible:
		_fail("R did not switch back to GLB")
		return
	var foot_toggle := InputEventKey.new()
	foot_toggle.keycode = KEY_G
	foot_toggle.pressed = true
	scene._input(foot_toggle)
	if not scene.physics_actor.foot_probe.show_debug:
		_fail("G did not enable two-foot ground targets")
		return
	scene._input(foot_toggle)
	if scene.physics_actor.foot_probe.show_debug:
		_fail("G did not disable ground targets")
		return
	var ik_toggle := InputEventKey.new()
	ik_toggle.keycode = KEY_I
	ik_toggle.pressed = true
	scene._input(ik_toggle)
	if scene.physics_actor.foot_ik.enabled_by_player:
		_fail("I did not deactivate terrain leg IK")
		return
	scene._input(ik_toggle)
	if not scene.physics_actor.foot_ik.enabled_by_player:
		_fail("I did not reactivate terrain leg IK")
		return
	var build_toggle := InputEventKey.new()
	build_toggle.keycode = KEY_B
	build_toggle.pressed = true
	scene._input(build_toggle)
	if not scene.composer.strict_build_rules or not scene.status_label.text.contains("validasi 3x3: ON"):
		_fail("B did not enable optional build guard")
		return
	scene._input(build_toggle)
	if scene.composer.strict_build_rules:
		_fail("B did not disable optional build guard")
		return
	var access_toggle := InputEventKey.new()
	access_toggle.keycode = KEY_N
	access_toggle.pressed = true
	scene._input(access_toggle)
	if not scene.show_access_overlay or scene.access_overlay == null or scene.access_overlay.get_node_or_null("AccessTileColors") == null:
		_fail("N did not show access regions")
		return
	var protect_toggle := InputEventKey.new()
	protect_toggle.keycode = KEY_K
	protect_toggle.pressed = true
	scene._input(protect_toggle)
	if not scene.composer.protect_connectivity or not scene.status_label.text.contains("lindungi jalur ON"):
		_fail("K did not enable access guard")
		return
	scene._input(protect_toggle)
	if scene.composer.protect_connectivity:
		_fail("K did not disable access guard")
		return
	var coast_toggle := InputEventKey.new()
	coast_toggle.keycode = KEY_O
	coast_toggle.pressed = true
	scene._input(coast_toggle)
	if not scene.coast_sculpt_mode or not scene.status_label.text.contains("ukir bibir luar ON"):
		_fail("coast sculpt UI mode not reflected in HUD")
		return
	scene._input(coast_toggle)
	if scene.coast_sculpt_mode:
		_fail("coast sculpt mode did not switch off")
		return
	var mask_toggle := InputEventKey.new()
	mask_toggle.keycode = KEY_T
	mask_toggle.pressed = true
	scene._input(mask_toggle)
	if not scene.land_mask_edit_mode or not scene.status_label.text.contains("edit topologi ON"):
		_fail("T did not enable topology editing mode")
		return
	scene._input(mask_toggle)
	if scene.land_mask_edit_mode:
		_fail("T did not disable topology editing mode")
		return
	if not scene.status_label.text.contains("WORLD LAB 48"):
		_fail("HUD still shows previous sprint")
		return
	print("PASS — zone, flow, rig, IK, build guard, access overlay, coast + mask modes and Lab 46 HUD")
	quit(0)


func _fail(message: String) -> void:
	push_error("FAIL — " + message)
	quit(1)
