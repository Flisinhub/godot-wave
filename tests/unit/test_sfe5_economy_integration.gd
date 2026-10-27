class_name TestSFE5EconomyIntegration
extends RefCounted

## Unit Test Suite for SFE5 Economy Integration & Lifecycle.
## Validates:
## 1. Initial minerals scaling (12000 / 15000 per player).
## 2. Dynamic supply calculations (80 base, -10/player, floor 30, outhouse stub).
## 3. SFEEconomyManager integration with IncomeFormula and KillContext.
## 4. Minerals by source and economy telemetry statistics.
## 5. Category color mappings for Floating Combat Text.

const GameSessionScript = preload("res://core/game_session.gd")
const GameConfigScript = preload("res://core/game_config.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const KillContext = preload("res://core/economy/kill_context.gd")
const IncomeParams = preload("res://core/economy/income_params.gd")
const IncomeFormula = preload("res://core/economy/income_formula.gd")

var _last_error: String = ""


func _pass() -> Dictionary:
	return {"passed": true}


func _fail(msg: String) -> Dictionary:
	_last_error = msg
	return {"passed": false, "error": msg}


func test_initial_minerals_and_scaling() -> Dictionary:
	var sess = GameSessionScript.new()
	
	# Solo player: normal 12000, random 15000
	sess.start_new_session(1, 1)
	if sess.get_initial_minerals(false) != 12000:
		return _fail("Expected 12000 initial minerals for solo normal hero, got %d" % sess.get_initial_minerals(false))
	if sess.get_initial_minerals(true) != 15000:
		return _fail("Expected 15000 initial minerals for solo random hero, got %d" % sess.get_initial_minerals(true))

	# 2 players: normal 6000, random 7500
	sess.start_new_session(1, 2)
	if sess.get_initial_minerals(false) != 6000:
		return _fail("Expected 6000 initial minerals for 2-player normal hero, got %d" % sess.get_initial_minerals(false))
	if sess.get_initial_minerals(true) != 7500:
		return _fail("Expected 7500 initial minerals for 2-player random hero, got %d" % sess.get_initial_minerals(true))

	# 6 players: normal 2000, random 2500
	sess.start_new_session(1, 6)
	if sess.get_initial_minerals(false) != 2000:
		return _fail("Expected 2000 initial minerals for 6-player normal hero, got %d" % sess.get_initial_minerals(false))
	if sess.get_initial_minerals(true) != 2500:
		return _fail("Expected 2500 initial minerals for 6-player random hero, got %d" % sess.get_initial_minerals(true))

	return _pass()


func test_supply_rules_and_penalties() -> Dictionary:
	var sess = GameSessionScript.new()

	# Solo: 80 supply
	sess.start_new_session(1, 1)
	if sess.get_max_supply() != 80:
		return _fail("Expected 80 max supply solo, got %d" % sess.get_max_supply())

	# 2 players: 70 supply
	sess.start_new_session(1, 2)
	if sess.get_max_supply() != 70:
		return _fail("Expected 70 max supply for 2 players, got %d" % sess.get_max_supply())

	# 6 players: 30 supply (floor)
	sess.start_new_session(1, 6)
	if sess.get_max_supply() != 30:
		return _fail("Expected 30 max supply for 6 players, got %d" % sess.get_max_supply())

	# 8 players: clamped to floor 30
	sess.start_new_session(1, 8)
	if sess.get_max_supply() != 30:
		return _fail("Expected 30 floor clamp for 8 players, got %d" % sess.get_max_supply())

	# Outhouse secret bonus stub: +10 supply
	sess.outhouse_secret_discovered = true
	if sess.get_max_supply() != 40:
		return _fail("Expected 40 supply with outhouse secret (30 floor + 10), got %d" % sess.get_max_supply())

	# Player leaving recalculates player count
	sess.outhouse_secret_discovered = false
	sess.start_new_session(1, 4) # 80 - 30 = 50
	if sess.get_max_supply() != 50:
		return _fail("Expected 50 supply for 4 players, got %d" % sess.get_max_supply())
	sess.on_player_left() # now 3 players -> 80 - 20 = 60
	if sess.get_max_supply() != 60:
		return _fail("Expected 60 supply after player leaves, got %d" % sess.get_max_supply())

	return _pass()


func test_economy_manager_income_formula_integration() -> Dictionary:
	var econ = SFEEconomyManager.new(12000)
	if econ.current_minerals != 12000:
		return _fail("Expected 12000 wallet, got %d" % econ.current_minerals)

	# Allied kill with IncomeParams for standard Zergling (Solo, Normal)
	var zerg_params = IncomeParams.new(35.0, 5.0, 0.7, "normal", 1.0, 1, 1.0)
	var kill_ctx = KillContext.new(null, null, 0, 0, 0, zerg_params)
	var bounty: int = econ.process_kill(kill_ctx)

	# Wiki expected for Zergling solo normal is 7 minerals
	if absi(bounty - 7) > 1:
		return _fail("Expected ~7 bounty for Zergling, got %d" % bounty)
	if econ.current_minerals != 12000 + bounty:
		return _fail("Wallet not credited correctly: %d vs %d" % [econ.current_minerals, 12000 + bounty])

	# Check telemetry recorded
	var telem = econ.last_kill_telemetry
	if telem.is_empty():
		return _fail("Telemetry empty after process_kill")
	if telem.get("category", "") != "normal":
		return _fail("Telemetry category mismatch: " + str(telem.get("category", "")))
	if telem.get("bounty", 0) != bounty:
		return _fail("Telemetry bounty mismatch")

	# Crossfire nullification with IncomeParams still awards 0
	var hostile_ctx = KillContext.new(null, null, 1, 0, 0, zerg_params)
	var hostile_bounty = econ.process_kill(hostile_ctx)
	if hostile_bounty != 0:
		return _fail("Hostile crossfire with IncomeParams must yield 0, got %d" % hostile_bounty)

	return _pass()


func test_economy_manager_stats_and_by_source() -> Dictionary:
	var econ = SFEEconomyManager.new(12000)

	# Add from various sources
	econ.add_minerals(500, "initial_bonus")
	econ.add_minerals(2500, "Pedestal Puzzle Solved")
	econ.add_minerals(100, "mission_credit")

	var stats = econ.get_economy_stats()
	var by_src = stats.get("by_source", {})
	if by_src.get("initial", 0) < 12500:
		return _fail("Expected at least 12500 initial minerals tracked, got %d" % by_src.get("initial", 0))
	if by_src.get("puzzle", 0) != 2500:
		return _fail("Expected 2500 puzzle minerals tracked, got %d" % by_src.get("puzzle", 0))
	if by_src.get("credit", 0) != 100:
		return _fail("Expected 100 credit minerals tracked, got %d" % by_src.get("credit", 0))

	# Minerals per minute calculation
	var mpm = econ.get_minerals_per_minute()
	if mpm <= 0.0:
		return _fail("Expected positive minerals per minute, got %.2f" % mpm)

	return _pass()


func test_category_colors_mapping() -> Dictionary:
	var struct_color: Color = GameConfigScript.get_category_color("structure")
	var hero_color: Color = GameConfigScript.get_category_color("heroic")
	var elite_color: Color = GameConfigScript.get_category_color("elite")
	var map_boss_color: Color = GameConfigScript.get_category_color("map_boss")
	var boss_color: Color = GameConfigScript.get_category_color("boss")
	var normal_color: Color = GameConfigScript.get_category_color("normal")

	# Check distinct colors per specification (green, yellow, orange, red, cyan)
	if not (struct_color.g > struct_color.r and struct_color.g > struct_color.b):
		return _fail("Structure color must be predominantly green")
	if not (hero_color.r > 0.8 and hero_color.g > 0.8 and hero_color.b < 0.5):
		return _fail("Heroic color must be predominantly yellow")
	if not (elite_color.r > elite_color.g and elite_color.g > 0.4 and elite_color.b < 0.3):
		return _fail("Elite color must be orange")
	if not (map_boss_color.r > map_boss_color.g and map_boss_color.g > 0.4 and map_boss_color.b < 0.3):
		return _fail("Map Boss color must be orange")
	if not (boss_color.r > 0.8 and boss_color.g < 0.4 and boss_color.b < 0.4):
		return _fail("Boss color must be predominantly red")
	if not (normal_color.b > 0.8 and normal_color.g > 0.8 and normal_color.r < 0.4):
		return _fail("Normal color must be cyan")

	return _pass()
