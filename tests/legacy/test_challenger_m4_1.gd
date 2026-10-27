extends SceneTree

# test_challenger_m4_1.gd
# Empirical Challenger 1 Adversarial Stress Test Suite for Milestone 4:
# Cinematic Real-Time Combat VFX & StarCraft II HUD Finishing
#
# Adversarial Stress Probes:
# 1. CombatVFXPool Zero-Allocation & Rapid Recycling Stress (1,000 rapid tracers & acid bursts)
# 2. CombatVFXPool Extreme Vector Edge Cases (zero distance, vertical alignment, sub-millimeter, tree safety)
# 3. StructureDamageVFX Multi-Tier Health Degradation & Zero-Division Resilience
# 4. Defensive Structures Scene Hierarchy & Pre-Attached DamageVFX Invariants
# 5. Mass Swarm Simulation 1,000 Units Tick-Time Benchmark (<16ms average)
# 6. SC2 HUD Console Procedural Styling, Gauge Color Transitions
# 7. SC2 Command Card Hero Skill Binding, Grid Layout & Out-of-Bounds Resilience
# 8. MainLevel Scene Declarations & BasePerimeter Hierarchy

const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const StructureDamageVFX = preload("res://core/vfx/structure_damage_vfx.gd")
const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SwarmUnitArchetype = preload("res://data/swarm/swarm_unit_archetype.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_log: Array[String] = []


func _init() -> void:
	print("\n\u001b[35m\u001b[1m====================================================================")
	print("=== EMPIRICAL CHALLENGER 1 ADVERSARIAL TEST SUITE (MILESTONE 4) ===")
	print("====================================================================\u001b[0m")
	var start_ms: int = Time.get_ticks_msec()

	_test_combat_vfx_pool_stress_and_zero_allocation()
	_test_combat_vfx_pool_vector_edge_cases()
	_test_structure_damage_vfx_state_transitions_and_edge_cases()
	_test_defensive_structures_scenes_and_damage_vfx_hierarchy()
	_test_swarm_simulation_1000_units_tick_time_benchmark()
	_test_sc2_hud_procedural_styling_and_state_stress()
	_test_sc2_command_card_hero_and_rapid_interaction()
	_test_main_level_scene_declarations()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n\u001b[35m====================================================================")
	print("Milestone 4 Challenger Results in %d ms: Total: %d, Passed: %d, Failed: %d" % [elapsed_ms, total_tests, passed_tests, failed_tests])
	if failed_tests > 0:
		print("\u001b[31m\u001b[1mVERDICT: ADVERSARIAL CHALLENGE DETECTED FAILURES! [REJECT]\u001b[0m")
		for f in failure_log:
			print("  [FAIL] %s" % f)
		print("====================================================================\n")
		quit(1)
	else:
		print("\u001b[32m\u001b[1mVERDICT: ALL ADVERSARIAL & EMPIRICAL CHALLENGES PASSED! [APPROVE]\u001b[0m")
		print("====================================================================\n")
		quit(0)


func _assert(condition: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		failure_log.append("%s: %s" % [test_name, error_msg])
		print("  \u001b[31m[FAIL]\u001b[0m %s - %s" % [test_name, error_msg])
		return false
	passed_tests += 1
	print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
	return true


# ==============================================================================
# Challenge 1: CombatVFXPool Rapid Stress & Zero-Allocation Invariance
# ==============================================================================
func _test_combat_vfx_pool_stress_and_zero_allocation() -> void:
	print("\n>> Challenge 1: CombatVFXPool 1,000-Iteration Stress & Zero Allocation...")

	var pool := CombatVFXPool.new()
	pool._ready()

	var initial_children: int = pool.get_child_count()
	_assert(initial_children == 44, "vfx_pool_initial_children_is_44", "Expected 44 children (24 tracers + 20 acid bursts), got %d" % initial_children)

	# Stress test: Fire 1,000 rapid tracers across varied trajectories
	for i in range(1000):
		var from_pos := Vector3(float(i % 10), 1.0, float((i / 10) % 10))
		var to_pos := Vector3(float(i % 50), 0.5, float(- (i % 50)))
		var tracer := pool.spawn_tracer(from_pos, to_pos)
		if tracer == null:
			_assert(false, "vfx_tracer_rapid_spawn", "spawn_tracer returned null on iteration %d" % i)
			break

	_assert(pool.get_child_count() == 44, "vfx_pool_tracers_zero_allocation", "Child count grew after 1,000 tracers: %d" % pool.get_child_count())
	_assert(pool._tracer_index == (1000 % 24), "vfx_tracer_index_correct_wrap", "Expected tracer index %d, got %d" % [1000 % 24, pool._tracer_index])

	# Stress test: Spawn 1,000 acid bursts over 200 simulated frames
	var bursts_spawned: int = 0
	var bursts_throttled: int = 0
	for frame in range(200):
		pool._process(0.016)
		# Request 10 bursts per frame (limit is 6 per frame)
		for b in range(10):
			var burst := pool.spawn_acid_burst(Vector3(float(b), 0.0, float(frame)))
			if burst != null:
				bursts_spawned += 1
			else:
				bursts_throttled += 1

	_assert(bursts_spawned == 200 * CombatVFXPool.MAX_BURSTS_PER_FRAME, "vfx_acid_burst_throttling_exact",
		"Expected %d allowed bursts, got %d" % [200 * CombatVFXPool.MAX_BURSTS_PER_FRAME, bursts_spawned])
	_assert(bursts_throttled == 200 * (10 - CombatVFXPool.MAX_BURSTS_PER_FRAME), "vfx_acid_burst_excess_throttled",
		"Expected %d throttled bursts, got %d" % [200 * (10 - CombatVFXPool.MAX_BURSTS_PER_FRAME), bursts_throttled])

	_assert(pool.get_child_count() == 44, "vfx_pool_acid_zero_allocation", "Child count grew after 2,000 burst requests: %d" % pool.get_child_count())
	_assert(pool._acid_index == (bursts_spawned % CombatVFXPool.ACID_BURST_POOL_SIZE), "vfx_acid_index_correct_wrap",
		"Expected acid index %d, got %d" % [bursts_spawned % CombatVFXPool.ACID_BURST_POOL_SIZE, pool._acid_index])

	pool.free()


# ==============================================================================
# Challenge 2: CombatVFXPool Extreme Vector Edge Cases
# ==============================================================================
func _test_combat_vfx_pool_vector_edge_cases() -> void:
	print("\n>> Challenge 2: CombatVFXPool Extreme Vector Edge Cases...")

	var pool := CombatVFXPool.new()
	pool._ready()

	# Case 1: from_pos == to_pos (zero length)
	var t1 := pool.spawn_tracer(Vector3(5, 5, 5), Vector3(5, 5, 5))
	_assert(t1 != null, "vfx_tracer_zero_distance", "spawn_tracer should handle zero-distance cleanly")

	# Case 2: Sub-millimeter distance (< 0.05 threshold)
	var t2 := pool.spawn_tracer(Vector3(1, 0, 1), Vector3(1.01, 0, 1.01))
	_assert(t2 != null, "vfx_tracer_submillimeter_distance", "spawn_tracer should handle sub-0.05m distances cleanly")

	# Case 3: Exactly parallel to Vector3.UP (dot product ~ 1.0)
	var t3 := pool.spawn_tracer(Vector3(0, 0, 0), Vector3(0, 10, 0))
	_assert(t3 != null, "vfx_tracer_vertical_up", "spawn_tracer should handle vertical up orientation without NaN")

	# Case 4: Exactly parallel to Vector3.DOWN (dot product ~ -1.0)
	var t4 := pool.spawn_tracer(Vector3(0, 10, 0), Vector3(0, 0, 0))
	_assert(t4 != null, "vfx_tracer_vertical_down", "spawn_tracer should handle vertical down orientation without NaN")

	# Case 5: Extremely distant coordinates (10,000 units away)
	var t5 := pool.spawn_tracer(Vector3(-5000, 0, -5000), Vector3(5000, 0, 5000))
	_assert(t5 != null, "vfx_tracer_extreme_distance", "spawn_tracer should handle extreme distances cleanly")

	# Case 6: Acid burst at origin and extreme coordinates
	var b1 := pool.spawn_acid_burst(Vector3.ZERO)
	_assert(b1 != null, "vfx_acid_burst_at_origin", "spawn_acid_burst at origin succeeded")
	var b2 := pool.spawn_acid_burst(Vector3(10000, -500, 10000))
	_assert(b2 != null, "vfx_acid_burst_extreme_coords", "spawn_acid_burst at extreme coords succeeded")

	pool.free()


# ==============================================================================
# Challenge 3: StructureDamageVFX Multi-Tier Health Degradation & Zero-Division
# ==============================================================================
func _test_structure_damage_vfx_state_transitions_and_edge_cases() -> void:
	print("\n>> Challenge 3: StructureDamageVFX State Transitions & Resilience...")

	var damage_vfx := StructureDamageVFX.new()
	damage_vfx._ready()
	damage_vfx._is_headless = false # Enable logical emitter checks

	# Verification of fine-grained health percentages
	# Clean: 100%, 90%, 75%, 71%
	for hp in [1000.0, 900.0, 750.0, 710.0]:
		damage_vfx.update_damage_state(hp, 1000.0)
		var clean_ok: bool = not damage_vfx.is_smoke_active() and not damage_vfx.is_fire_active() and not damage_vfx.is_sparks_active()
		_assert(clean_ok, "damage_vfx_clean_at_%d_pct" % int(hp / 10.0), "Expected clean state at %f HP" % hp)

	# Moderate: 70%, 65%, 50%, 36%
	for hp in [700.0, 650.0, 500.0, 360.0]:
		damage_vfx.update_damage_state(hp, 1000.0)
		var mod_ok: bool = damage_vfx.is_smoke_active() and not damage_vfx.is_fire_active() and not damage_vfx.is_sparks_active()
		_assert(mod_ok, "damage_vfx_moderate_at_%d_pct" % int(hp / 10.0), "Expected moderate smoke-only state at %f HP" % hp)

	# Critical: 35%, 25%, 10%, 1%
	for hp in [350.0, 250.0, 100.0, 10.0]:
		damage_vfx.update_damage_state(hp, 1000.0)
		var crit_ok: bool = damage_vfx.is_smoke_active() and damage_vfx.is_fire_active() and damage_vfx.is_sparks_active()
		_assert(crit_ok, "damage_vfx_critical_at_%d_pct" % int(hp / 10.0), "Expected critical smoke+fire+sparks state at %f HP" % hp)

	# Destroyed: 0% and negative HP (-200 HP)
	damage_vfx.update_damage_state(0.0, 1000.0)
	_assert(damage_vfx.is_smoke_active() and damage_vfx.is_fire_active(), "damage_vfx_zero_hp", "Destroyed state (0 HP) active")

	damage_vfx.update_damage_state(-250.0, 1000.0)
	_assert(damage_vfx.is_smoke_active() and damage_vfx.is_fire_active(), "damage_vfx_negative_hp", "Destroyed state (-250 HP) active")

	# Edge case: max_hp = 0.0 or negative max_hp (must not crash due to maxf(1.0, max_hp))
	damage_vfx.update_damage_state(50.0, 0.0)
	_assert(true, "damage_vfx_zero_max_hp_resilience", "Did not crash with max_hp = 0.0")

	damage_vfx.update_damage_state(50.0, -100.0)
	_assert(true, "damage_vfx_negative_max_hp_resilience", "Did not crash with max_hp = -100.0")

	# Re-verify headless safety
	damage_vfx._is_headless = true
	damage_vfx.update_damage_state(10.0, 1000.0)
	_assert(not damage_vfx.smoke_particles.emitting and not damage_vfx.fire_particles.emitting and not damage_vfx.sparks_particles.emitting,
		"damage_vfx_headless_guard_prevents_particles", "Particles must not emit when _is_headless is true")

	damage_vfx.free()


# ==============================================================================
# Challenge 4: Defensive Structures Scene Hierarchy & Pre-Attached DamageVFX
# ==============================================================================
func _test_defensive_structures_scenes_and_damage_vfx_hierarchy() -> void:
	print("\n>> Challenge 4: Defensive Structures Scene Hierarchy & DamageVFX...")

	var structure_scenes: Dictionary = {
		"command_center": {"path": "res://entities/structures/command_center.tscn", "box_str": "Vector3(8, 4, 8)"},
		"wall_segment": {"path": "res://entities/structures/wall_segment.tscn", "box_str": "Vector3(4, 3.2, 1.2)"},
		"gate_structure": {"path": "res://entities/structures/gate_structure.tscn", "box_str": "Vector3(4, 3.3, 0.6)"},
		"bunker_structure": {"path": "res://entities/structures/bunker_structure.tscn", "box_str": "Vector3(3.5, 2.5, 3.5)"}
	}

	for key in structure_scenes.keys():
		var info: Dictionary = structure_scenes[key]
		var scene_text := FileAccess.get_file_as_string(info["path"])
		_assert(not scene_text.is_empty(), "scene_readable_%s" % key, "Failed to read scene file %s" % info["path"])

		# Check DamageVFX node declaration
		_assert(scene_text.contains('name="DamageVFX"'), "damage_vfx_declared_%s" % key, "Scene %s missing DamageVFX node" % key)

		# Check collision box size declaration
		var size_str: String = info["box_str"]
		_assert(scene_text.contains(size_str), "collision_box_exact_%s" % key,
			"Expected collision box %s in %s" % [size_str, key])

		# Specific contracts for gate
		if key == "gate_structure":
			_assert(scene_text.contains('name="StatusLight"'), "gate_status_light_declared", "Gate missing StatusLight node")
			_assert(scene_text.contains('name="DoorSlidingPart"'), "gate_door_sliding_declared", "Gate missing DoorSlidingPart node")


# ==============================================================================
# Challenge 5: SwarmSimulation 1,000 Units Tick-Time Benchmark (<16ms average)
# ==============================================================================
func _test_swarm_simulation_1000_units_tick_time_benchmark() -> void:
	print("\n>> Challenge 5: Mass Swarm Simulation 1,000-Unit Benchmark (<16ms)...")

	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 2048)
	sim.register_goal(Vector3.ZERO)

	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	_assert(zerg_arch != null, "zergling_archetype_loaded", "zergling_archetype.tres must load")
	if zerg_arch:
		sim.register_archetype(zerg_arch)

	# Spawn 1,000 active swarm units
	var spawn_indices: Array[int] = sim.spawn_wave(0, 1000, Vector3(0, 0, 30), 20.0)
	_assert(spawn_indices.size() == 1000, "spawned_1000_swarm_units", "Expected 1000 units spawned, got %d" % spawn_indices.size())
	_assert(sim.get_active_unit_count() == 1000, "active_swarm_count_1000", "Expected active_count 1000, got %d" % sim.get_active_unit_count())

	# Warm-up 10 ticks
	for w in range(10):
		sim.simulate_step(0.016)

	# Benchmark 100 steps
	var tick_times_usec: Array[int] = []
	var total_usec: int = 0
	const BENCHMARK_STEPS: int = 100

	for s in range(BENCHMARK_STEPS):
		var t0: int = Time.get_ticks_usec()
		sim.simulate_step(0.016)
		var dt_usec: int = Time.get_ticks_usec() - t0
		tick_times_usec.append(dt_usec)
		total_usec += dt_usec

	var avg_ms: float = (float(total_usec) / float(BENCHMARK_STEPS)) / 1000.0
	tick_times_usec.sort()
	var p95_ms: float = float(tick_times_usec[int(BENCHMARK_STEPS * 0.95)]) / 1000.0
	var max_ms: float = float(tick_times_usec[BENCHMARK_STEPS - 1]) / 1000.0
	var min_ms: float = float(tick_times_usec[0]) / 1000.0

	print("  [BENCHMARK] 1,000 Swarm Units (100 steps): Avg=%.2f ms, P95=%.2f ms, Max=%.2f ms, Min=%.2f ms" % [avg_ms, p95_ms, max_ms, min_ms])

	# Specification invariant: average tick time strictly under 16.0 ms
	_assert(avg_ms < 16.0, "swarm_1000_units_avg_under_16ms", "Average tick time %.2f ms must be < 16.0 ms (60 FPS budget)" % avg_ms)

	sim.free()


# ==============================================================================
# Challenge 6: SC2 HUD Console Procedural Styling, Gauge Color Transitions
# ==============================================================================
func _test_sc2_hud_procedural_styling_and_state_stress() -> void:
	print("\n>> Challenge 6: SC2 HUD Console Procedural Styling & Gauge Transitions...")

	# 1. SC2HUDRoot layout and theme
	var hud := SC2HUDRoot.new()
	hud._build_hud_layout()

	var root_ctrl: Control = hud.get_node_or_null("HUDControlRoot")
	_assert(root_ctrl != null, "hud_control_root_exists", "HUDControlRoot must exist")

	var console_bg: Panel = root_ctrl.get_node_or_null("ConsoleBackground") as Panel if root_ctrl else null
	_assert(console_bg != null, "hud_console_background_exists", "ConsoleBackground panel must exist")
	if console_bg:
		var style: StyleBoxFlat = console_bg.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(style != null, "hud_console_style_flat", "ConsoleBackground style must be StyleBoxFlat")
		if style:
			_assert(style.border_width_top > 0, "hud_console_top_border", "ConsoleBackground must have top border seam")

	hud.free()

	# 2. SC2StatPanel HP color progression stress test
	var stat_panel := SC2StatPanel.new()
	stat_panel._build_ui_layout()

	# Sweep HP from 100% down to 0% in steps of 5%
	for pct in range(100, -5, -5):
		var hp_val: float = float(pct)
		stat_panel._update_hp_bar_color(hp_val, 100.0)
		var col: Color = stat_panel._hp_fill_style.bg_color

		if pct > 50:
			_assert(col.g > col.r, "stat_panel_hp_color_green_dominant_%d" % pct, "HP color should be green-dominant at %d%%" % pct)
		elif pct > 25:
			_assert(col.r > 0.7 and col.g > 0.5, "stat_panel_hp_color_amber_%d" % pct, "HP color should be amber/yellow at %d%%" % pct)
		else:
			_assert(col.r > col.g, "stat_panel_hp_color_red_dominant_%d" % pct, "HP color should be red-dominant at %d%%" % pct)

	stat_panel.free()


# ==============================================================================
# Challenge 7: SC2CommandCard Hero & Rapid Interaction Stress
# ==============================================================================
func _test_sc2_command_card_hero_and_rapid_interaction() -> void:
	print("\n>> Challenge 7: SC2CommandCard Hero Binding & Interaction Stress...")

	var card := SC2CommandCard.new()
	card._setup_procedural_grid()

	_assert(card.slot_buttons.size() == 15, "command_card_15_slots", "CommandCard must have 15 slot buttons")

	# Test out of bounds slot clicks (must not crash)
	card._on_slot_pressed(-1)
	card._on_slot_pressed(999)
	_assert(true, "command_card_oob_clicks_safe", "Out of bounds slot clicks handled cleanly")

	# Test clicking on empty/disabled slots (must not crash)
	for i in range(15):
		card._on_slot_pressed(i)
	_assert(true, "command_card_empty_slot_clicks_safe", "Empty slot clicks handled cleanly")

	# Test binding with HeroUnit3D
	var hero := HeroUnit3D.new()
	_assert(hero.has_method("cast_skill"), "hero_has_cast_skill_method", "HeroUnit3D must have cast_skill")
	_assert(hero.hero_data != null, "hero_has_hero_data", "HeroUnit3D must have hero_data")

	# Ensure test hero has at least 1 skill in hero_data
	if hero.hero_data.skills.is_empty():
		var test_skill := HeroSkillData.new()
		test_skill.skill_id = "test_stim"
		test_skill.skill_name = "Stimpack"
		test_skill.hotkey = "T"
		test_skill.energy_cost = 20.0
		test_skill.cooldown = 3.0
		hero.hero_data.skills.append(test_skill)

	card.populate_for_unit(hero)

	# Slot 0 should be bound to hero's first skill
	var s0: Dictionary = card.slot_data[0]
	_assert(s0.get("type") == "skill", "hero_slot_0_is_skill", "Expected slot 0 to be skill, got: %s" % str(s0))
	_assert(not s0.get("hotkey", "").is_empty(), "hero_slot_0_has_hotkey", "Expected non-empty hotkey on slot 0")

	# Click slot 0 (should emit command_triggered and invoke cast_skill without crash)
	var signal_state := {"emitted": false}
	card.command_triggered.connect(func(cmd_id, payload):
		signal_state["emitted"] = true
	)
	card._on_slot_pressed(0)
	_assert(signal_state["emitted"], "command_triggered_emitted_on_skill_click", "command_triggered signal was emitted")

	hero.free()

	# Clear card
	card.clear_card()
	for s in range(15):
		var btn: Button = card.slot_buttons[s]
		_assert(btn.text == "" and btn.disabled == true, "command_slot_%d_cleared" % s, "Slot %d should be cleared and disabled" % s)

	card.free()


# ==============================================================================
# Challenge 8: MainLevel Scene Declarations & BasePerimeter Hierarchy
# ==============================================================================
func _test_main_level_scene_declarations() -> void:
	print("\n>> Challenge 8: MainLevel Scene Declarations & BasePerimeter Hierarchy...")

	var main_text := FileAccess.get_file_as_string("res://levels/main_level.tscn")
	_assert(not main_text.is_empty(), "main_level_tscn_readable", "main_level.tscn must be readable")

	# Verify CombatVFXPool node declaration in scene
	_assert(main_text.contains('[node name="CombatVFXPool" type="Node3D" parent="."]'),
		"main_level_has_combat_vfx_pool_node", "main_level.tscn must declare CombatVFXPool node")

	# Verify SC2HUDRoot node declaration in scene
	_assert(main_text.contains('[node name="SC2HUDRoot" type="CanvasLayer" parent="."]'),
		"main_level_has_sc2_hud_root_node", "main_level.tscn must declare SC2HUDRoot node")

	# Verify SwarmSimulation node declaration in scene
	_assert(main_text.contains('[node name="SwarmSimulation" type="Node3D" parent="."]'),
		"main_level_has_swarm_simulation_node", "main_level.tscn must declare SwarmSimulation node")

	# Count defensive structures in BasePerimeter
	var cc_count := main_text.count('ExtResource("5_cc_scene")')
	var gate_count := main_text.count('ExtResource("6_gate_scene")')
	var wall_count := main_text.count('ExtResource("7_wall_scene")')
	var bunker_count := main_text.count('ExtResource("19_bunker_script")')
	var total_structures := cc_count + gate_count + wall_count + bunker_count

	print("  [STRUCTURE INVENTORY] CommandCenter: %d, Gates: %d, Bunkers: %d, Walls: %d (Total: %d)" % [
		cc_count, gate_count, bunker_count, wall_count, total_structures
	])

	_assert(cc_count == 1, "cc_in_main_level", "CommandCenter present in BasePerimeter (count: %d)" % cc_count)
	_assert(gate_count == 2, "gates_in_main_level", "Exactly 2 Gates present in BasePerimeter (count: %d)" % gate_count)
	_assert(bunker_count == 2, "bunkers_in_main_level", "Exactly 2 Bunkers present in BasePerimeter (count: %d)" % bunker_count)
	_assert(wall_count == 25, "walls_in_main_level", "Exactly 25 Walls present in BasePerimeter (count: %d)" % wall_count)
	_assert(total_structures == 30, "total_30_structures_in_main_level", "Exactly 30 total defensive structures present (count: %d)" % total_structures)
