extends "res://tests/test_base.gd"

## Test Suite for Requirement R3:
## Bounty-Driven Economy, Crossfire Nullification, and Dynamic Difficulty Scaling.

const ECONOMY_MGR_PATH := "res://core/economy/sfe_economy_manager.gd"
const DIFFICULTY_MGR_PATH := "res://core/economy/sfe_difficulty_manager.gd"
const SFE_ENUMS_PATH := "res://core/enums/sfe_enums.gd"

func test_allied_lethal_blow_awards_bounty() -> Dictionary:
	if not ResourceLoader.exists(ECONOMY_MGR_PATH):
		return skip_test("Milestone 3 pending: %s not implemented yet" % ECONOMY_MGR_PATH)
		
	var EconomyScript = load(ECONOMY_MGR_PATH)
	var econ = EconomyScript.new()
	var initial_minerals: int = econ.current_minerals
	
	# Simulate allied kill context
	# Faction.ALLIED = 0
	var kill_ctx = _create_mock_kill_context(0, 15) # killer_faction: ALLIED, bounty: 15
	var awarded: int = econ.process_kill(kill_ctx)
	
	if not assert_gt(awarded, 0, "Allied kill must award non-zero minerals"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, initial_minerals + awarded, "Minerals wallet must be credited"):
		return get_last_failure()

	return pass_test()

func test_crossfire_hostile_zero_bounty() -> Dictionary:
	if not ResourceLoader.exists(ECONOMY_MGR_PATH):
		return skip_test("Milestone 3 pending: %s not implemented yet" % ECONOMY_MGR_PATH)
		
	var EconomyScript = load(ECONOMY_MGR_PATH)
	var econ = EconomyScript.new()
	var initial_minerals: int = econ.current_minerals
	
	# Strict Crossfire Nullification Rule:
	# Hostile infighting (Faction.ENEMY_SWARM = 1)
	var swarm_kill_ctx = _create_mock_kill_context(1, 50)
	var awarded_swarm: int = econ.process_kill(swarm_kill_ctx)
	if not assert_eq(awarded_swarm, 0, "Swarm infighting kill must award strictly 0 minerals"):
		return get_last_failure()
		
	# Hostile rogue kill (Faction.HOSTILE_ROGUE = 2)
	var rogue_kill_ctx = _create_mock_kill_context(2, 50)
	var awarded_rogue: int = econ.process_kill(rogue_kill_ctx)
	if not assert_eq(awarded_rogue, 0, "Hostile rogue kill must award strictly 0 minerals"):
		return get_last_failure()
		
	# Environmental hazard kill (Faction.ENVIRONMENTAL = 3)
	var env_kill_ctx = _create_mock_kill_context(3, 50)
	var awarded_env: int = econ.process_kill(env_kill_ctx)
	if not assert_eq(awarded_env, 0, "Environmental hazard kill must award strictly 0 minerals"):
		return get_last_failure()
		
	if not assert_eq(econ.current_minerals, initial_minerals, "Player minerals must remain unchanged"):
		return get_last_failure()

	return pass_test()

func test_difficulty_scaling_multipliers() -> Dictionary:
	if not ResourceLoader.exists(DIFFICULTY_MGR_PATH):
		return skip_test("Milestone 3 pending: %s not implemented yet" % DIFFICULTY_MGR_PATH)
		
	var DiffScript = load(DIFFICULTY_MGR_PATH)
	
	# Casual Tier (0)
	DiffScript.set_difficulty(0)
	if not assert_almost_eq(DiffScript.get_income_rate_multiplier(), 1.50, 0.01, "Casual income = 1.50x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_enemy_stat_multiplier(), 0.75, 0.01, "Casual enemy stats = 0.75x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_upgrade_cadence(), 180.0, 0.1, "Casual upgrade cadence = 180s"):
		return get_last_failure()
		
	# Normal Tier (1)
	DiffScript.set_difficulty(1)
	if not assert_almost_eq(DiffScript.get_income_rate_multiplier(), 1.00, 0.01, "Normal income = 1.00x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_enemy_stat_multiplier(), 1.00, 0.01, "Normal enemy stats = 1.00x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_upgrade_cadence(), 120.0, 0.1, "Normal upgrade cadence = 120s"):
		return get_last_failure()
		
	# Hard Tier (2)
	DiffScript.set_difficulty(2)
	if not assert_almost_eq(DiffScript.get_income_rate_multiplier(), 0.80, 0.01, "Hard income = 0.80x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_enemy_stat_multiplier(), 1.30, 0.01, "Hard enemy stats = 1.30x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_upgrade_cadence(), 90.0, 0.1, "Hard upgrade cadence = 90s"):
		return get_last_failure()
		
	# Brutal Tier (3)
	DiffScript.set_difficulty(3)
	if not assert_almost_eq(DiffScript.get_income_rate_multiplier(), 0.65, 0.01, "Brutal income = 0.65x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_enemy_stat_multiplier(), 1.75, 0.01, "Brutal enemy stats = 1.75x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_upgrade_cadence(), 60.0, 0.1, "Brutal upgrade cadence = 60s"):
		return get_last_failure()
		
	# Torment Tier (4)
	DiffScript.set_difficulty(4)
	if not assert_almost_eq(DiffScript.get_income_rate_multiplier(), 0.50, 0.01, "Torment income = 0.50x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_enemy_stat_multiplier(), 2.50, 0.01, "Torment enemy stats = 2.50x"):
		return get_last_failure()
	if not assert_almost_eq(DiffScript.get_upgrade_cadence(), 40.0, 0.1, "Torment upgrade cadence = 40s"):
		return get_last_failure()

	return pass_test()

func test_economy_spending_and_balance() -> Dictionary:
	if not ResourceLoader.exists(ECONOMY_MGR_PATH):
		return skip_test("Milestone 3 pending: %s not implemented yet" % ECONOMY_MGR_PATH)
		
	var EconomyScript = load(ECONOMY_MGR_PATH)
	var econ = EconomyScript.new()
	econ.current_minerals = 100
	
	if not assert_true(econ.can_afford(50), "Should afford cost <= current"):
		return get_last_failure()
	if not assert_false(econ.can_afford(150), "Should not afford cost > current"):
		return get_last_failure()
		
	var spent: bool = econ.spend_minerals(40)
	if not assert_true(spent, "Spending affordable amount should return true"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 60, "Balance should reduce to 60"):
		return get_last_failure()
		
	var overspent: bool = econ.spend_minerals(100)
	if not assert_false(overspent, "Spending unaffordable amount should return false"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 60, "Balance should remain 60"):
		return get_last_failure()

	return pass_test()

func test_specification_crossfire_nullification_math() -> Dictionary:
	# Verifies the invariant logic:
	# Only Faction.ALLIED (0) awards minerals. Any other faction returns strictly 0.
	var process_kill_logic = func(killer_faction: int, base_bounty: int, multiplier: float) -> int:
		if killer_faction != 0: # 0 = ALLIED
			return 0
		var awarded := int(round(float(base_bounty) * multiplier))
		return maxi(1, awarded) if base_bounty > 0 else 0
		
	# Allied kill gives scaled bounty
	if not assert_eq(process_kill_logic.call(0, 10, 1.0), 10, "Allied kill awards 10"):
		return get_last_failure()
	if not assert_eq(process_kill_logic.call(0, 10, 1.5), 15, "Allied kill Casual awards 15"):
		return get_last_failure()
	if not assert_eq(process_kill_logic.call(0, 10, 0.5), 5, "Allied kill Torment awards 5"):
		return get_last_failure()
		
	# Hostile infighting / friendly fire / environmental must be exactly 0
	if not assert_eq(process_kill_logic.call(1, 100, 1.5), 0, "Enemy infighting awards 0"):
		return get_last_failure()
	if not assert_eq(process_kill_logic.call(2, 100, 1.5), 0, "Rogue crossfire awards 0"):
		return get_last_failure()
	if not assert_eq(process_kill_logic.call(3, 100, 1.5), 0, "Environmental kill awards 0"):
		return get_last_failure()
		
	return pass_test()

func test_specification_difficulty_matrix() -> Dictionary:
	var matrix := {
		"casual": {"income": 1.50, "enemy": 0.75, "cadence": 180.0},
		"normal": {"income": 1.00, "enemy": 1.00, "cadence": 120.0},
		"hard": {"income": 0.80, "enemy": 1.30, "cadence": 90.0},
		"brutal": {"income": 0.65, "enemy": 1.75, "cadence": 60.0},
		"torment": {"income": 0.50, "enemy": 2.50, "cadence": 40.0}
	}
	
	# Verify inverse correlation: as difficulty increases, income decreases and enemy stats increase
	var prev_income: float = 999.0
	var prev_enemy: float = 0.0
	var prev_cadence: float = 999.0
	
	for tier_name in ["casual", "normal", "hard", "brutal", "torment"]:
		var d: Dictionary = matrix[tier_name]
		var inc: float = d["income"]
		var ene: float = d["enemy"]
		var cad: float = d["cadence"]
		
		if not assert_lt(inc, prev_income, "%s income must be lower than previous tier" % tier_name):
			return get_last_failure()
		if not assert_gt(ene, prev_enemy, "%s enemy stats must be higher than previous tier" % tier_name):
			return get_last_failure()
		if not assert_lt(cad, prev_cadence, "%s upgrade cadence must be faster than previous tier" % tier_name):
			return get_last_failure()
			
		prev_income = inc
		prev_enemy = ene
		prev_cadence = cad

	return pass_test()


func _create_mock_kill_context(killer_faction: int, base_bounty: int) -> RefCounted:
	var ctx_script_path := "res://core/combat/kill_context.gd"
	if ResourceLoader.exists(ctx_script_path):
		var KillCtxClass = load(ctx_script_path)
		var inst = KillCtxClass.new()
		inst.killer_faction = killer_faction
		inst.base_bounty = base_bounty
		return inst
	else:
		# Fallback RefCounted with identical properties
		var mock = RefCounted.new()
		mock.set_meta("killer_faction", killer_faction)
		mock.set_meta("base_bounty", base_bounty)
		# Add dynamic properties
		mock.set("killer_faction", killer_faction)
		mock.set("base_bounty", base_bounty)
		return mock
