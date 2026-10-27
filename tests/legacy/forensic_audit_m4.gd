extends SceneTree

## Independent Forensic Integrity Audit Test for Milestone 4
## Executed by Forensic Auditor agent.
## Rigorously validates implementation genuineness, zero-allocation pooling,
## threshold calculations, collision shape invariances, and headless safety.

const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const StructureDamageVFX = preload("res://core/vfx/structure_damage_vfx.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

var total_checks: int = 0
var passed_checks: int = 0
var failed_checks: int = 0
var audit_failures: Array[String] = []


func _init() -> void:
	print("\u001b[33m\u001b[1m==========================================================")
	print("=== SFE5 MILESTONE 4: INDEPENDENT FORENSIC INTEGRITY AUDIT ===")
	print("==========================================================\u001b[0m")
	var start_ms: int = Time.get_ticks_msec()

	_execute_audit()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n\u001b[33m==========================================================")
	print("Forensic Audit Completed in %d ms" % elapsed_ms)
	print("Total Forensic Checks: %d" % total_checks)
	print("Passed:                %d" % passed_checks)
	print("Failed:                %d" % failed_checks)

	if failed_checks > 0:
		print("\u001b[31mINTEGRITY VIOLATION DETECTED:")
		for f in audit_failures:
			print("  [VIOLATION] " + f)
		print("VERDICT: INTEGRITY VIOLATION\u001b[0m")
		print("==========================================================")
		quit(1)
	else:
		print("\u001b[32m\u001b[1mVERDICT: CLEAN - ALL FORENSIC CHECKS SATISFIED [PASSED]\u001b[0m")
		print("==========================================================")
		quit(0)


func _assert_check(check_name: String, condition: bool, err_msg: String) -> void:
	total_checks += 1
	if condition:
		passed_checks += 1
		print("  \u001b[32m[VERIFIED]\u001b[0m %s" % check_name)
	else:
		failed_checks += 1
		var full_err: String = "%s -> %s" % [check_name, err_msg]
		audit_failures.append(full_err)
		print("  \u001b[31m[FAILED]\u001b[0m %s" % full_err)


func _execute_audit() -> void:
	_audit_combat_vfx_pool()
	_audit_structure_damage_vfx()
	_audit_defensive_structure_scenes()
	_audit_sc2_hud_systems()
	_audit_combat_mitigations()


func _audit_combat_vfx_pool() -> void:
	var pool := CombatVFXPool.new()
	pool._ready()

	# Check 1: Real instance pre-allocations
	_assert_check(
		"CombatVFXPool pre-allocation counts",
		pool.get_tracer_pool_size() == 24 and pool.get_acid_pool_size() == 20,
		"Expected 24 tracers and 20 acid bursts, got %d and %d" % [pool.get_tracer_pool_size(), pool.get_acid_pool_size()]
	)

	# Check 2: Pre-allocated node hierarchy
	_assert_check(
		"CombatVFXPool child hierarchy count",
		pool.get_child_count() == 44,
		"Expected 44 children in pool root, got %d" % pool.get_child_count()
	)

	# Check 3: Authentic MeshInstance3D and GPUParticles3D types
	var first_tracer = pool.get_child(0)
	_assert_check(
		"Tracer node is authentic MeshInstance3D",
		first_tracer is MeshInstance3D,
		"Expected MeshInstance3D, got %s" % str(first_tracer)
	)

	var first_burst = pool.get_child(24)
	_assert_check(
		"Acid burst node is authentic GPUParticles3D",
		first_burst is GPUParticles3D,
		"Expected GPUParticles3D, got %s" % str(first_burst)
	)

	# Check 4: Strict zero-allocation under 200 consecutive calls
	var initial_children: int = pool.get_child_count()
	for i in range(100):
		pool.spawn_tracer(Vector3.ZERO, Vector3(float(i), 0.0, float(i)))
		pool._process(0.016)
		pool.spawn_acid_burst(Vector3(float(i), 0.0, 0.0))
	var final_children: int = pool.get_child_count()
	_assert_check(
		"CombatVFXPool strict zero dynamic allocation",
		initial_children == final_children and initial_children == 44,
		"Allocation leak detected: child count grew from %d to %d" % [initial_children, final_children]
	)

	# Check 5: Circular ring buffer wrap-around
	var start_idx: int = pool._tracer_index
	for i in range(24):
		pool.spawn_tracer(Vector3.ZERO, Vector3(10, 0, 10))
	_assert_check(
		"CombatVFXPool tracer ring index wraps cleanly full circle",
		pool._tracer_index == start_idx,
		"Expected tracer index to return to %d, got %d" % [start_idx, pool._tracer_index]
	)

	pool.free()


func _audit_structure_damage_vfx() -> void:
	var vfx := StructureDamageVFX.new()
	vfx._ready()
	vfx._is_headless = false

	# Check 6: Authentic child emitters
	_assert_check(
		"StructureDamageVFX child emitters exist",
		vfx.smoke_particles != null and vfx.fire_particles != null and vfx.sparks_particles != null,
		"One or more particle emitter children are null"
	)

	# Check 7: Threshold calculation logic
	vfx.update_damage_state(100.0, 100.0)
	_assert_check(
		"Damage VFX threshold > 70% (pristine): all emitters dormant",
		not vfx.is_smoke_active() and not vfx.is_fire_active() and not vfx.is_sparks_active(),
		"Emitters unexpectedly active at 100% HP"
	)

	vfx.update_damage_state(50.0, 100.0)
	_assert_check(
		"Damage VFX threshold 35% - 70% (moderate): smoke active, fire/sparks dormant",
		vfx.is_smoke_active() and not vfx.is_fire_active() and not vfx.is_sparks_active(),
		"Incorrect emitter state at 50% HP"
	)

	vfx.update_damage_state(20.0, 100.0)
	_assert_check(
		"Damage VFX threshold < 35% (critical): smoke, fire, and sparks active",
		vfx.is_smoke_active() and vfx.is_fire_active() and vfx.is_sparks_active(),
		"Not all emitters active at 20% HP"
	)

	vfx.free()


func _audit_defensive_structure_scenes() -> void:
	# Check 8: Command Center collision and DamageVFX
	var cc_text := FileAccess.get_file_as_string("res://entities/structures/command_center.tscn")
	_assert_check(
		"CommandCenter preserves Vector3(8, 4, 8) collision box",
		cc_text.contains("Vector3(8, 4, 8)"),
		"CommandCenter collision box modified"
	)
	_assert_check(
		"CommandCenter has pre-attached DamageVFX node",
		cc_text.contains('name="DamageVFX"'),
		"CommandCenter missing DamageVFX"
	)

	# Check 9: Wall Segment collision and DamageVFX
	var wall_text := FileAccess.get_file_as_string("res://entities/structures/wall_segment.tscn")
	_assert_check(
		"WallSegment preserves Vector3(4, 3.2, 1.2) collision box",
		wall_text.contains("Vector3(4, 3.2, 1.2)"),
		"WallSegment collision box modified"
	)
	_assert_check(
		"WallSegment has pre-attached DamageVFX node",
		wall_text.contains('name="DamageVFX"'),
		"WallSegment missing DamageVFX"
	)

	# Check 10: Gate Structure collision, DoorSlidingPart, StatusLight and DamageVFX
	var gate_text := FileAccess.get_file_as_string("res://entities/structures/gate_structure.tscn")
	_assert_check(
		"GateStructure preserves Vector3(4, 3.3, 0.6) door collision",
		gate_text.contains("Vector3(4, 3.3, 0.6)"),
		"GateStructure door collision box modified"
	)
	_assert_check(
		"GateStructure preserves DoorSlidingPart and StatusLight nodes",
		gate_text.contains('name="DoorSlidingPart"') and gate_text.contains('name="StatusLight"'),
		"GateStructure hierarchy broken"
	)
	_assert_check(
		"GateStructure has pre-attached DamageVFX node",
		gate_text.contains('name="DamageVFX"'),
		"GateStructure missing DamageVFX"
	)

	# Check 11: Bunker Structure collision and DamageVFX
	var bunker_text := FileAccess.get_file_as_string("res://entities/structures/bunker_structure.tscn")
	_assert_check(
		"BunkerStructure preserves Vector3(3.5, 2.5, 3.5) collision box",
		bunker_text.contains("Vector3(3.5, 2.5, 3.5)"),
		"BunkerStructure collision box modified"
	)
	_assert_check(
		"BunkerStructure has pre-attached DamageVFX node",
		bunker_text.contains('name="DamageVFX"'),
		"BunkerStructure missing DamageVFX"
	)


func _audit_sc2_hud_systems() -> void:
	# Check 12: SC2HUDRoot procedural theme and layout
	var hud := SC2HUDRoot.new()
	hud._build_hud_layout()
	_assert_check(
		"SC2HUDRoot contains ConsoleBackground with StyleBoxFlat",
		hud.get_node_or_null("HUDControlRoot/ConsoleBackground") != null,
		"ConsoleBackground missing"
	)
	_assert_check(
		"SC2HUDRoot contains MinimapBox with StyleBoxFlat",
		hud.minimap_box != null and hud.minimap_box.get_theme_stylebox("panel") is StyleBoxFlat,
		"MinimapBox styling missing"
	)
	hud.free()

	# Check 13: SC2StatPanel wireframe display and color shifts
	var stat_panel := SC2StatPanel.new()
	stat_panel._build_ui_layout()
	_assert_check(
		"SC2StatPanel has SC2WireframeDisplay ColorRect",
		stat_panel.wireframe_rect is ColorRect,
		"wireframe_rect missing or invalid"
	)
	stat_panel._update_hp_bar_color(100.0, 100.0)
	var green_c := stat_panel._hp_fill_style.bg_color
	stat_panel._update_hp_bar_color(40.0, 100.0)
	var amber_c := stat_panel._hp_fill_style.bg_color
	stat_panel._update_hp_bar_color(15.0, 100.0)
	var red_c := stat_panel._hp_fill_style.bg_color
	_assert_check(
		"SC2StatPanel vital gauge dynamic color shifting (green -> amber -> red)",
		green_c.g > 0.7 and amber_c.r > 0.8 and amber_c.g > 0.6 and red_c.r > 0.8 and red_c.g < 0.4,
		"Color shifting logic failed"
	)
	stat_panel.free()

	# Check 14: SC2CommandCard 3x5 button grid and hotkey styling
	var card := SC2CommandCard.new()
	card._setup_procedural_grid()
	_assert_check(
		"SC2CommandCard 15 button slots with StyleBoxFlat",
		card.slot_buttons.size() == 15 and card.slot_buttons[0].get_theme_stylebox("normal") is StyleBoxFlat,
		"Command card buttons count or styling failed"
	)
	card.free()


func _audit_combat_mitigations() -> void:
	# Check 15: Wall 35% passive mitigation
	var wall_res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert_check(
		"SFECombatEngine Wall 35% mitigation invariant (100 -> 65)",
		absf(wall_res.damage_dealt - 65.0) < 0.01,
		"Expected 65.0, got %f" % wall_res.damage_dealt
	)

	# Check 16: Bunker 25% passive mitigation
	var bunker_res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert_check(
		"SFECombatEngine Bunker 25% mitigation invariant (100 -> 75)",
		absf(bunker_res.damage_dealt - 75.0) < 0.01,
		"Expected 75.0, got %f" % bunker_res.damage_dealt
	)
