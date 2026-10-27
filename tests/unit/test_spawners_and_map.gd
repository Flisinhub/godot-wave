class_name TestSpawnersAndMap
extends RefCounted

## TestSpawnersAndMap - Unit & Integration Test Suite for SFE5 Fase 3.
## Covers:
## 1. Task 3.8: Armor Piercing calculation in SFECombatEngine.
## 2. Task 3.T1: SpawnerNode locked invulnerability and sequential unlocking in SpawnerChain.
## 3. Task 3.T2: EnemyBudgetManager 300 unit budget clamp and production resumption.
## 4. Task 3.T3: MapSeed determinism and identical layout signature hash.
## 5. Task 3.T4: EnemyClassRegistry colored enemy mutation upon spawner destruction.

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const SpawnerChain = preload("res://core/spawners/spawner_chain.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")
const EnemyClassRegistry = preload("res://core/spawners/enemy_class_registry.gd")
const MapSeed = preload("res://core/map/map_seed.gd")
const MapGenerator = preload("res://core/map/map_generator.gd")

var passed_count: int = 0
var failed_count: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed_count += 1
		push_error("Assertion Failed: " + message)
		assert(condition, message)
	else:
		passed_count += 1


## Test 1: Task 3.8 - SFECombatEngine ignores_armor flag
func test_armor_piercing_bypasses_flat_armor() -> void:
	var raw_damage := 50.0
	var flat_armor := 15.0
	
	# Normal physical attack: 50 - 15 = 35 effective damage
	var normal_res := SFECombatEngine.calculate_damage(
		raw_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		flat_armor,
		0, 0, false, false, false, 0.0, -1.0, 0,
		false # ignores_armor = false
	)
	_assert(is_equal_approx(normal_res.effective_damage, 35.0), "Normal attack mitigated by armor")
	
	# Armor piercing attack: 50 damage ignores 15 armor -> 50 effective damage
	var piercing_res := SFECombatEngine.calculate_damage(
		raw_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		flat_armor,
		0, 0, false, false, false, 0.0, -1.0, 0,
		true # ignores_armor = true
	)
	_assert(is_equal_approx(piercing_res.effective_damage, 50.0), "Piercing attack completely bypasses flat armor")


## Test 2: Task 3.T1 - Locked spawner takes 0 damage; unlocks and takes damage when predecessor dies
func test_spawner_locked_invulnerability_and_chain_unlocking() -> void:
	var chain := SpawnerChain.new()
	
	var spawner_a := SpawnerNode.new()
	spawner_a.spawner_id = &"spawner_01"
	spawner_a.max_health = 1000.0
	spawner_a.current_health = 1000.0
	spawner_a.structure_armor = 0.0
	
	var spawner_b := SpawnerNode.new()
	spawner_b.spawner_id = &"spawner_02"
	spawner_b.max_health = 1500.0
	spawner_b.current_health = 1500.0
	spawner_b.structure_armor = 0.0
	
	chain.register_spawner(spawner_a, &"")
	chain.register_spawner(spawner_b, &"spawner_01")
	
	_assert(spawner_a.current_state == SpawnerNode.State.ACTIVE, "Spawner A starts ACTIVE")
	_assert(spawner_b.current_state == SpawnerNode.State.LOCKED, "Spawner B starts LOCKED")
	
	# Strike Spawner B while LOCKED: must deal 0 damage and remain at full health
	var dmg_taken := spawner_b.take_damage(200.0)
	_assert(is_equal_approx(dmg_taken, 0.0), "Locked spawner B takes 0 damage")
	_assert(is_equal_approx(spawner_b.current_health, 1500.0), "Locked spawner B health untouched")
	
	# Destroy Spawner A
	spawner_a.take_damage(1200.0)
	_assert(spawner_a.current_state == SpawnerNode.State.DESTROYED, "Spawner A destroyed")
	
	# Spawner B must now be UNLOCKED and ACTIVE
	_assert(spawner_b.current_state == SpawnerNode.State.ACTIVE, "Spawner B unlocked into ACTIVE state")
	
	# Strike Spawner B now: takes full damage
	dmg_taken = spawner_b.take_damage(300.0)
	_assert(is_equal_approx(dmg_taken, 300.0), "Unlocked spawner B takes damage")
	_assert(is_equal_approx(spawner_b.current_health, 1200.0), "Spawner B health reduced to 1200")
	
	# Destroy Spawner B: chain completes
	var chain_completed := [false]
	chain.all_spawners_destroyed.connect(func(): chain_completed[0] = true)
	spawner_b.take_damage(1500.0)
	
	_assert(chain.is_all_destroyed(), "All spawners in chain are destroyed")
	_assert(chain_completed[0], "Chain completion signal emitted")


## Test 3: Task 3.T2 - Budget clamping: at 300 living units, spawner halts production; drops to 299, resumes
func test_enemy_budget_clamping_and_resumption() -> void:
	var budget := EnemyBudgetManager.new(300)
	
	_assert(budget.can_spawn(10), "Budget allows spawning 10 units when empty")
	_assert(not budget.is_saturated(), "Budget not saturated initially")
	
	# Create simulated extra enemy nodes to reach exactly 300
	var mock_enemies: Array[Node] = []
	for i in range(300):
		var n := Node.new()
		mock_enemies.append(n)
		budget.register_extra_enemy(n)
	
	_assert(budget.get_living_count() == 300, "Living enemy count is exactly 300")
	_assert(budget.is_saturated(), "Budget is saturated at 300")
	_assert(not budget.can_spawn(1), "Cannot spawn even 1 unit when at 300 budget")
	
	# SpawnerNode cycle attempt under saturated budget
	var spawner := SpawnerNode.new()
	spawner.spawner_id = &"test_spawner"
	spawner.group_size = 4
	spawner.cycle_seconds = 20.0
	spawner.budget_manager = budget
	spawner.set_spawner_state(SpawnerNode.State.ACTIVE)
	
	# Advance cycle timer to 20s
	spawner._physics_process(20.5)
	_assert(is_equal_approx(spawner.cycle_timer, 20.0), "Cycle timer paused at 20.0s waiting for budget")
	
	# Eliminate 1 enemy -> drops to 299
	budget.unregister_extra_enemy(mock_enemies.pop_back())
	_assert(budget.get_living_count() == 299, "Living count dropped to 299")
	_assert(not budget.is_saturated(), "Budget no longer saturated")
	_assert(budget.can_spawn(1), "Can spawn 1 unit at 299")
	
	# Cleanup mock nodes
	for m in mock_enemies:
		m.free()


## Test 4: Task 3.T3 - Deterministic seed produces identical map layout plan and signature
func test_map_seed_determinism_and_layout_signature() -> void:
	var seed_val := 4815162342
	
	var seed1 := MapSeed.new(seed_val)
	var gen1 := MapGenerator.new(seed1)
	var plan1 := gen1.generate_layout_plan(3)
	var sig1 := gen1.get_layout_signature(plan1)
	
	var seed2 := MapSeed.new(seed_val)
	var gen2 := MapGenerator.new(seed2)
	var plan2 := gen2.generate_layout_plan(3)
	var sig2 := gen2.get_layout_signature(plan2)
	
	_assert(plan1.size() == 3, "Plan 1 has 3 spawners")
	_assert(plan2.size() == 3, "Plan 2 has 3 spawners")
	_assert(sig1 == sig2, "Exact signature match between identical seeds")
	_assert(plan1[0]["position"] == plan2[0]["position"], "Spawner 1 position match")
	_assert(plan1[1]["family_id"] == plan2[1]["family_id"], "Spawner 2 family match")
	_assert(plan1[2]["health"] == plan2[2]["health"], "Spawner 3 health match")
	
	# Different seed produces different layout
	var seed3 := MapSeed.new(999999)
	var gen3 := MapGenerator.new(seed3)
	var plan3 := gen3.generate_layout_plan(3)
	var sig3 := gen3.get_layout_signature(plan3)
	_assert(sig1 != sig3, "Different seed produces distinct layout signature")


## Test 5: Task 3.T4 - Colored Enemy mutation upon spawner destruction
func test_colored_enemy_class_mutation() -> void:
	var registry := EnemyClassRegistry.new()
	
	var zerg_info := registry.get_class_info("zergling")
	_assert(zerg_info["tier"] == 0, "Zerglings start at mutation tier 0")
	_assert(is_equal_approx(zerg_info["hp_mult"], 1.0), "Initial HP multiplier 1.0")
	_assert(zerg_info["color"] == Color.WHITE, "Initial color is white")
	
	# Destroy Zergling Spawner
	var mutated := registry.mutate_class_on_spawner_destroyed("zergling")
	_assert(mutated["tier"] == 1, "Zergling class promoted to mutation tier 1")
	_assert(mutated["hp_mult"] > 1.4, "Zergling HP jumped by +45%")
	_assert(mutated["dmg_mult"] > 1.3, "Zergling Damage jumped by +35%")
	_assert(mutated["speed_mult"] > 1.1, "Zergling Speed jumped by +15%")
	_assert(mutated["color"] == EnemyClassRegistry.MUTATION_PALETTE[0], "Zergling acquired Tier 1 Neon Cyan tint")
	
	# Second destruction on same class: advances to Tier 2 (Fiery Crimson)
	var mutated_t2 := registry.mutate_class_on_spawner_destroyed("zergling")
	_assert(mutated_t2["tier"] == 2, "Promoted to tier 2")
	_assert(mutated_t2["color"] == EnemyClassRegistry.MUTATION_PALETTE[1], "Acquired Tier 2 Fiery Crimson tint")
