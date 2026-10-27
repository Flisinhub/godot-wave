class_name TestPlayerConsoleAndBuffs
extends RefCounted

## TestPlayerConsoleAndBuffs - Verification Suite for SFE5 Fase 4.
## Covers:
## 1. Task 4.T1: Momentum motion stack accumulation (0..5) and dissipation on stop.
## 2. Task 4.T2: One buff per tier restriction & partial refund on replacement.
## 3. Task 4.T3: Demiurge cheat-death mechanic and 180s cooldown timer.
## 4. Task 4.T4: Máxima Experiencia (Level 100) formula and level-based refund calculation.
## 5. Task 4.T5: StatsComponent attribute formulas and Shift+Click max investment.

const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const GameConfig = preload("res://core/game_config.gd")

var passed_count: int = 0
var failed_count: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed_count += 1
		push_error("Assertion Failed: " + message)
		assert(condition, message)
	else:
		passed_count += 1


## Test 1: Task 4.T1 - Momentum stacks while moving, dissipates when stopped
func test_momentum_stack_accumulation_and_decay() -> void:
	var buffs := BuffComponent.new()
	buffs.equip_tier_buff(3, "momentum", "Momentum", 750)
	
	_assert(buffs.has_buff("momentum"), "Momentum is equipped")
	_assert(buffs.momentum_stacks == 0, "Momentum starts at 0 stacks")
	
	# Simulate 5 motion ticks
	for i in range(5):
		buffs.update_conditions(0.6, 5.0, 1.0) # Moving at 5.0 m/s
	
	_assert(buffs.momentum_stacks == 5, "Momentum reaches max 5 stacks while moving")
	var dmg_mult := buffs.get_damage_multiplier(false)
	_assert(is_equal_approx(dmg_mult, 1.25), "5 stacks of Momentum grant +25% damage")
	
	# Further movement does not exceed cap of 5
	buffs.update_conditions(0.6, 5.0, 1.0)
	_assert(buffs.momentum_stacks == 5, "Momentum remains clamped at 5 stacks")
	
	# Unit stops moving: speed = 0.0 -> Momentum immediately resets to 0
	buffs.update_conditions(0.1, 0.0, 1.0)
	_assert(buffs.momentum_stacks == 0, "Momentum dissipates immediately upon stopping")
	_assert(is_equal_approx(buffs.get_damage_multiplier(false), 1.0), "Damage returns to 1.0x baseline")


## Test 2: Task 4.T2 - One buff per tier restriction and replacement refund
func test_one_buff_per_tier_and_replacement() -> void:
	var buffs := BuffComponent.new()
	
	# Equip Tier 3 Momentum
	var res1 := buffs.equip_tier_buff(3, "momentum", "Momentum", 750)
	_assert(res1["replaced_id"] == "", "No previous buff replaced")
	_assert(res1["refund"] == 0, "Zero refund on first equip")
	_assert(buffs.has_buff("momentum"), "Momentum is equipped in Tier 3")
	
	# Equip Tier 3 Predator (replaces Momentum in Tier 3)
	var res2 := buffs.equip_tier_buff(3, "predator", "Predator", 850)
	_assert(res2["replaced_id"] == "momentum", "Replaced Momentum")
	_assert(res2["refund"] == 375, "Refunded 50% of 750 minerals = 375")
	_assert(buffs.has_buff("predator"), "Predator is now equipped in Tier 3")
	_assert(not buffs.has_buff("momentum"), "Momentum was replaced and removed")
	
	# Check tier 3 lookup
	var t3 := buffs.get_buff_in_tier(3)
	_assert(t3["id"] == "predator", "Tier 3 slot holds Predator")


## Test 3: Task 4.T3 - Demiurge cheat-death mechanic and 180s cooldown
func test_demiurge_cheat_death_and_cooldown() -> void:
	var buffs := BuffComponent.new()
	
	_assert(not buffs.attempt_cheat_death(), "Cannot cheat death without Demiurge")
	
	# Unlock Demiurge
	buffs.unlock_demiurge()
	_assert(buffs.demiurge_available, "Demiurge is ready")
	
	# Fatal damage occurs -> Cheat death triggers!
	var saved := buffs.attempt_cheat_death()
	_assert(saved, "Demiurge successfully cancelled death")
	_assert(not buffs.demiurge_available, "Demiurge enters cooldown")
	_assert(is_equal_approx(buffs.demiurge_cooldown_timer, 180.0), "Cooldown set to exactly 180 seconds")
	
	# Second fatal damage while on cooldown cannot save unit
	var saved_again := buffs.attempt_cheat_death()
	_assert(not saved_again, "Cannot cheat death while on cooldown")
	
	# Advance time by 100s -> still on cooldown
	buffs.update_conditions(100.0, 0.0)
	_assert(not buffs.demiurge_available, "Still on cooldown after 100s")
	
	# Advance remaining 80s -> ready again
	buffs.update_conditions(80.5, 0.0)
	_assert(buffs.demiurge_available, "Demiurge re-arms after 180s cooldown elapses")


## Test 4: Task 4.T4 - Máxima Experiencia (Level 100) formula and level-based refund
func test_maxima_experiencia_cost_and_refund() -> void:
	var buffs := BuffComponent.new()
	
	# Level 1 Hero: 75000 - (1 * 750) = 74,250 minerals
	var cost_lvl1 := buffs.calculate_maxima_experiencia_cost(1)
	_assert(cost_lvl1 == 74250, "Level 1 cost is 74,250")
	
	# Level 20 Hero: 75000 - (20 * 750) = 75000 - 15000 = 60,000 minerals
	var cost_lvl20 := buffs.calculate_maxima_experiencia_cost(20)
	_assert(cost_lvl20 == 60000, "Level 20 cost is 60,000")
	
	# Level 50 Hero: 75000 - (50 * 750) = 75000 - 37500 = 37,500 minerals
	var cost_lvl50 := buffs.calculate_maxima_experiencia_cost(50)
	_assert(cost_lvl50 == 37500, "Level 50 cost is 37,500")
	
	# Level 100 Hero: 75000 - (100 * 750) = 0 minerals
	var cost_lvl100 := buffs.calculate_maxima_experiencia_cost(100)
	_assert(cost_lvl100 == 0, "Level 100 cost is 0 minerals")
	
	# Purchase execution
	var purchase := buffs.purchase_maxima_experiencia(20, 100000)
	_assert(purchase["success"], "Purchase succeeded")
	_assert(purchase["cost"] == 60000, "Spent 60,000 minerals")
	_assert(purchase["remaining"] == 40000, "Remaining 40,000 minerals")


## Test 5: Task 4.T5 - StatsComponent attribute progression & Shift+Click max investment
func test_stats_component_and_shift_click_investment() -> void:
	var stats := StatsComponent.new()
	stats.base_max_hp = 700.0
	stats.base_damage = 40.0
	stats.recalculate()
	
	_assert(is_equal_approx(stats.get_effective_max_hp(), 700.0), "Initial HP 700")
	_assert(is_equal_approx(stats.get_effective_damage(), 40.0), "Initial Damage 40")
	
	# Invest 10 points into Fuerza (Strength)
	stats.invest_attribute("strength", 10)
	# +15 HP per point -> +150 HP = 850 HP
	# +0.8 Damage per point -> +8.0 Damage = 48.0 Damage
	_assert(is_equal_approx(stats.get_effective_max_hp(), 850.0), "HP scaled to 850 with 10 STR")
	_assert(is_equal_approx(stats.get_effective_damage(), 48.0), "Damage scaled to 48 with 10 STR")
	
	# Shift+Click: Invest 1000 minerals into Destreza
	# Cost per point is 50 minerals initially (tier 0: 0..9)
	var shift_res := stats.invest_max_possible("dexterity", 1000)
	_assert(shift_res["points_bought"] > 15, "Bought at least 15 DEX points with 1000 minerals")
	_assert(shift_res["remaining_minerals"] < 60, "Spent nearly all minerals on DEX")
	_assert(stats.dexterity == shift_res["points_bought"], "DEX points successfully applied")
	_assert(stats.get_effective_attack_period() < stats.base_attack_period, "Attack speed accelerated")
