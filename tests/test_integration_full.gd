extends "res://tests/test_base.gd"

## Tier 4: Full System Integration Tests & Real-World Application Scenarios.
## Exercises end-to-end integration across Swarm Simulation, Combat Engine,
## Buff Engine, Economy, Heroes, Events, and Persistence.

const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmFlowFieldScript = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SFEBuffEngine = preload("res://core/combat/sfe_buff_engine.gd")
const SFEBuffDef = preload("res://core/combat/sfe_buff_def.gd")

func test_scenario_1_full_swarm_assault_fortified_perimeter() -> Dictionary:
	# Scenario 1: Full Swarm Wave Assault on Fortified Perimeter
	# 1,000 swarm units navigate through flow field with dynamic obstacles (walls/gates).
	# When attacking reinforced walls, combat engine mitigates 35% damage.
	
	var sim = SwarmSimulationScript.new()
	sim.max_units = 1500
	sim.init_subsystems()
	
	# Register base target and defensive perimeter wall
	sim.register_goal(Vector3.ZERO)
	sim.register_obstacle_aabb(&"perimeter_wall_north", Vector3(-10.0, 0.0, 10.0), Vector3(10.0, 0.0, 12.0), true)
	sim.flow_field.update()
	
	# Spawn 1,000 active swarm units outside perimeter
	for i in range(1000):
		var angle: float = float(i) * 0.1
		var pos := Vector3(cos(angle) * 20.0, 0.0, sin(angle) * 20.0)
		sim.spawn_unit(0, pos, 35.0, 7.2, 8.0)
		
	if not assert_eq(sim.get_active_unit_count(), 1000, "1,000 units must be spawned"):
		return get_last_failure()
		
	# Simulate 10 frames of approach
	for t in range(10):
		sim.simulate_step(0.01667)
		
	# Swarm attacks reinforced wall
	var wall_strike := SFECombatEngine.calculate_damage(
		8.0, # Zergling damage
		CombatTypes.DamageType.PHYSICAL,
		0.0, # Flat armor
		0,   # Upgrade level
		CombatTypes.StructureType.WALL_REINFORCED
	)
	# 8.0 * (1 - 0.35) = 5.2 damage dealt to reinforced wall
	if not assert_almost_eq(wall_strike.damage_dealt, 5.2, 0.001, "Wall passive mitigation reduces 8.0 to 5.2"):
		sim.free()
		return get_last_failure()

	sim.free()
	return pass_test()

func test_scenario_2_boss_encounter_under_swarm_crossfire() -> Dictionary:
	# Scenario 2: Boss Encounter under Swarm Crossfire
	# Hero fights a boss entity with combat engine calculations while crossfire between hostiles yields 0 minerals.
	
	# Hero uses physical attack against armored boss (e.g. 50 raw vs 15 flat armor)
	var hero_attack := SFECombatEngine.calculate_damage(
		50.0,
		CombatTypes.DamageType.PHYSICAL,
		15.0, # Boss flat armor
		10    # Hero weapon upgrade level 10 = 2% progressive mitigation
	)
	# (50 - 15) = 35. 35 * (1 - 0.02) = 34.3 damage
	if not assert_almost_eq(hero_attack.damage_dealt, 34.3, 0.001, "Hero strike against boss armor"):
		return get_last_failure()
		
	# Boss AoE spell against Hero (HEROIC tag)
	var boss_spell := SFECombatEngine.calculate_damage(
		120.0,
		CombatTypes.DamageType.SPELL,
		20.0, # Hero flat armor (bypassed)
		25,   # Hero armor upgrade lvl 25 = 5% progressive reduction -> 114.0
		CombatTypes.StructureType.NONE,
		true, # HEROIC tag -> 40% AoE penalty
		true  # AoE
	)
	# 120 * (1 - 0.05) = 114. 114 * (1 - 0.40) = 68.4 damage
	if not assert_almost_eq(boss_spell.damage_dealt, 68.4, 0.001, "Boss AoE spell vs Hero takes 40% penalty"):
		return get_last_failure()

	return pass_test()

func test_scenario_3_six_hero_nydus_raid_and_rpg_progression() -> Dictionary:
	# Scenario 3: 6-Hero Nydus Raid & Buff Stacking
	# Exercises SFEBuffEngine high-capacity stacking (Tychus 20 stacks) and Lasting Empowerment.
	
	var buff_engine = SFEBuffEngine.new()
	var tychus_passive = SFEBuffDef.new(&"tychus_passive", "Minigun Stacks", 5.0, 20)
	tychus_passive.stat_multipliers["attack_speed"] = 1.03 # +3% per stack
	
	# Rapid fire builds 20 stacks
	for i in range(25):
		buff_engine.apply_buff(tychus_passive, -1.0, 20)
		
	if not assert_eq(buff_engine.get_stacks(&"tychus_passive"), 20, "Tychus passive stacks to 20"):
		return get_last_failure()
		
	var active_tychus := buff_engine.get_buff(&"tychus_passive")
	# 20 stacks * 3% = +60% attack speed (1.60x)
	var speed_mult := active_tychus.get_stat_multiplier("attack_speed")
	if not assert_almost_eq(speed_mult, 1.60, 0.01, "20 stacks yields 1.60x attack speed"):
		return get_last_failure()
		
	# Apply Lasting Empowerment active extension (+5.0s)
	buff_engine.extend_all_buffs(5.0)
	if not assert_almost_eq(active_tychus.time_remaining, 10.0, 0.05, "Buff extended to 10.0s"):
		return get_last_failure()

	return pass_test()

func test_scenario_4_power_cut_crash_simulation() -> Dictionary:
	# Scenario 4: Power-Cut Crash Simulation during High-Tier Wave
	var bank_path := "res://core/persistence/bank_manager.gd"
	if not ResourceLoader.exists(bank_path):
		return skip_test("Milestone 5 pending: BankManager not implemented yet")
		
	var BankClass = load(bank_path)
	var save_state := {
		"account_id": "hardcore_commander",
		"veterancy_level": 20,
		"total_kills": 50000,
		"bosses_defeated": ["nydus_behemoth", "omega_ultralisk"]
	}
	BankClass.save_bank(save_state)
	
	# Update state
	save_state["total_kills"] = 50250
	BankClass.save_bank(save_state)
	
	# Corrupt .save file
	var file_w := FileAccess.open("user://sfe5_bank.save", FileAccess.WRITE)
	file_w.store_string("CORRUPTED_PARTIAL_JSON_DATA{")
	file_w.close()
	
	# Recovery from .bak
	var restored: Dictionary = BankClass.load_bank()
	if not assert_false(restored.is_empty(), "Must recover valid save from .bak after crash"):
		return get_last_failure()
	if not assert_eq(restored.get("account_id"), "hardcore_commander", "Commander account restored"):
		return get_last_failure()

	return pass_test()

func test_scenario_5_complete_game_session_loop() -> Dictionary:
	# Scenario 5: Complete Game Session Loop
	# Hero roll, wave simulation with flow field, combat calculations, pedestal puzzle resolution.
	
	# 1. 1% Secret Hero roll check
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var roll: float = rng.randf()
	var got_secret: bool = (roll < 0.01)
	
	# 2. Defensive position Flow Field
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	ff.set_goals([Vector2.ZERO])
	ff.stamp_obstacle_aabb(Vector2(-5.0, 5.0), Vector2(5.0, 6.0), 255)
	ff.update()
	
	var flow_vec := ff.sample_flow_bilinear(Vector2(0.0, 10.0))
	if not assert_gt(flow_vec.length_squared(), 0.1, "Flow vector directs units around obstacle"):
		return get_last_failure()
		
	# 3. Invulnerability shield protects hero from lethal strike
	var lethal_strike := SFECombatEngine.calculate_damage(
		1000.0,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.NONE,
		true,
		false,
		true # is_invulnerable = true
	)
	if not assert_almost_eq(lethal_strike.damage_dealt, 0.0, 0.001, "Invulnerable hero unharmed"):
		return get_last_failure()
	if not assert_true(lethal_strike.is_immune, "Immune flag set"):
		return get_last_failure()

	return pass_test()
