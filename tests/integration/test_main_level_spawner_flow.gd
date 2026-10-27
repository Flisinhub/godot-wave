extends "res://tests/test_base.gd"

## Integration Test for Main Level Spawner Network & Progression Flow (R1 Paso 1.8).
## Validates:
## - Spawner chain initialization (count = 3)
## - Sequential locking: Spawner 1 ACTIVE, Spawners 2 & 3 LOCKED
## - Sequential unlocking upon predecessor destruction
## - Budget manager saturation clamp (300 units) and resumption

const MapSeed = preload("res://core/map/map_seed.gd")
const MapGenerator = preload("res://core/map/map_generator.gd")
const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const SpawnerChain = preload("res://core/spawners/spawner_chain.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")
const GameConfig = preload("res://core/game_config.gd")


func test_spawner_chain_initialization_and_states() -> Dictionary:
	var seed_obj := MapSeed.new(12345)
	var generator := MapGenerator.new(seed_obj)
	var budget := EnemyBudgetManager.new(300)
	var parent_node := Node3D.new()

	var plan := generator.generate_layout_plan(3)
	if not assert_eq(plan.size(), 3, "Plan must contain exactly 3 spawner slots"):
		parent_node.free()
		return get_last_failure()

	var chain: SpawnerChain = generator.spawn_spawner_chain(parent_node, plan, budget, null)
	if not assert_eq(chain.get_total_spawner_count(), 3, "Chain must have registered 3 spawners"):
		parent_node.free()
		return get_last_failure()

	var sp1 = chain.get_spawner(&"spawner_01")
	var sp2 = chain.get_spawner(&"spawner_02")
	var sp3 = chain.get_spawner(&"spawner_03")

	if not assert_true(sp1 != null and sp2 != null and sp3 != null, "All 3 spawners must be present in chain"):
		parent_node.free()
		return get_last_failure()

	if not assert_eq(sp1.current_state, SpawnerNode.State.ACTIVE, "Spawner 1 must be ACTIVE initially"):
		parent_node.free()
		return get_last_failure()

	if not assert_eq(sp2.current_state, SpawnerNode.State.LOCKED, "Spawner 2 must be LOCKED initially"):
		parent_node.free()
		return get_last_failure()

	if not assert_eq(sp3.current_state, SpawnerNode.State.LOCKED, "Spawner 3 must be LOCKED initially"):
		parent_node.free()
		return get_last_failure()

	parent_node.free()
	return pass_test()


func test_spawner_sequential_defeat_and_unlock_flow() -> Dictionary:
	var seed_obj := MapSeed.new(45678)
	var generator := MapGenerator.new(seed_obj)
	var budget := EnemyBudgetManager.new(300)
	var parent_node := Node3D.new()

	var plan := generator.generate_layout_plan(3)
	var chain: SpawnerChain = generator.spawn_spawner_chain(parent_node, plan, budget, null)

	var sp1: SpawnerNode = chain.get_spawner(&"spawner_01")
	var sp2: SpawnerNode = chain.get_spawner(&"spawner_02")
	var sp3: SpawnerNode = chain.get_spawner(&"spawner_03")

	# Locked spawner cannot take damage
	var locked_dmg: float = sp2.take_damage(500.0)
	if not assert_eq(locked_dmg, 0.0, "Locked Spawner 2 must take 0 damage"):
		parent_node.free()
		return get_last_failure()

	# Destroy Spawner 1
	sp1.take_damage(sp1.max_health + 100.0)
	if not assert_eq(sp1.current_state, SpawnerNode.State.DESTROYED, "Spawner 1 must be DESTROYED"):
		parent_node.free()
		return get_last_failure()

	# Spawner 2 must now be ACTIVE
	if not assert_eq(sp2.current_state, SpawnerNode.State.ACTIVE, "Spawner 2 must transition to ACTIVE"):
		parent_node.free()
		return get_last_failure()

	# Spawner 3 must remain LOCKED
	if not assert_eq(sp3.current_state, SpawnerNode.State.LOCKED, "Spawner 3 must remain LOCKED"):
		parent_node.free()
		return get_last_failure()

	# Destroy Spawner 2 -> Unlocks Spawner 3
	sp2.take_damage(sp2.max_health + 100.0)
	if not assert_eq(sp2.current_state, SpawnerNode.State.DESTROYED, "Spawner 2 must be DESTROYED"):
		parent_node.free()
		return get_last_failure()
	if not assert_eq(sp3.current_state, SpawnerNode.State.ACTIVE, "Spawner 3 must transition to ACTIVE"):
		parent_node.free()
		return get_last_failure()

	# Track completion signal
	var chain_cleared := [false]
	chain.all_spawners_destroyed.connect(func(): chain_cleared[0] = true)

	# Destroy Spawner 3 -> All cleared
	sp3.take_damage(sp3.max_health + 100.0)
	if not assert_eq(sp3.current_state, SpawnerNode.State.DESTROYED, "Spawner 3 must be DESTROYED"):
		parent_node.free()
		return get_last_failure()

	if not assert_true(chain.is_all_destroyed(), "All spawners must be destroyed"):
		parent_node.free()
		return get_last_failure()

	if not assert_true(chain_cleared[0], "all_spawners_destroyed signal must have been emitted"):
		parent_node.free()
		return get_last_failure()

	parent_node.free()
	return pass_test()


func test_budget_saturation_clamping_and_resumption() -> Dictionary:
	var budget := EnemyBudgetManager.new(300)

	if not assert_true(budget.can_spawn(50), "Budget allows spawning within limit"):
		return get_last_failure()

	var dummy_nodes: Array[Node] = []
	for i in range(300):
		var n := Node.new()
		dummy_nodes.append(n)
		budget.register_extra_enemy(n)

	if not assert_eq(budget.get_living_count(), 300, "Living count must be 300"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	if not assert_true(budget.is_saturated(), "Budget must be saturated at 300"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	if not assert_false(budget.can_spawn(1), "Cannot spawn when saturated"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	# Free 5 nodes to drop count to 295
	for i in range(5):
		var n = dummy_nodes.pop_back()
		budget.unregister_extra_enemy(n)
		n.free()

	if not assert_eq(budget.get_living_count(), 295, "Living count must drop to 295"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	if not assert_false(budget.is_saturated(), "Budget must not be saturated at 295"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	if not assert_true(budget.can_spawn(5), "Budget can spawn 5 units when at 295"):
		for n in dummy_nodes: n.free()
		return get_last_failure()

	for n in dummy_nodes:
		n.free()
	return pass_test()
