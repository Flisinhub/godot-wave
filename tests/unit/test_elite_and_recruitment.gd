class_name TestEliteAndRecruitment
extends RefCounted

## TestEliteAndRecruitment - Verification Suite for SFE5 Fase 6 (Elite Units, Veterancy & Support).
## Covers:
## 1. EliteComponent promotion, kill stack accumulation up to +125 flat damage and x1.6667 attack speed.
## 2. Attack cooldown scaling under elite veterancy.
## 3. UnitRecruitmentManager supply cap enforcement, mineral validation, and spawning.
## 4. Veterancy purchase converting standard units into Elite units.
## 5. Vision unit Ace invulnerability (Observer / Blimp).
## 6. Category ring color styling (Task 6.8).

const EliteComponent = preload("res://core/components/elite_component.gd")
const BaseUnit3DScript = preload("res://entities/allies/base_unit_3d.gd")
const UnitRecruitmentManager = preload("res://core/recruitment/unit_recruitment_manager.gd")
const CategoryRingStyler = preload("res://core/vfx/category_ring_styler.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")

var passed_count: int = 0
var failed_count: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed_count += 1
		push_error("Assertion Failed: " + message)
		assert(condition, message)
	else:
		passed_count += 1


## Test 1: Tasks 6.1 & 6.2 - EliteComponent stack accumulation, +125 damage and 1.6667x attack speed cap
func test_elite_component_stack_progression_and_caps() -> void:
	var elite := EliteComponent.new()
	_assert(not elite.is_elite, "Initially not elite")
	_assert(elite.elite_stacks == 0, "Starts at 0 stacks")
	_assert(is_equal_approx(elite.get_bonus_damage(), 0.0), "0 stacks -> 0 bonus damage")
	_assert(is_equal_approx(elite.get_attack_speed_multiplier(), 1.0), "0 stacks -> 1.0x attack speed")

	# Promote to elite
	elite.promote_to_elite()
	_assert(elite.is_elite, "Promoted to elite")

	# Add 25 kills
	for i in range(25):
		elite.add_kill()
	_assert(elite.elite_stacks == 25, "Accumulated 25 stacks")
	_assert(is_equal_approx(elite.get_bonus_damage(), 25.0), "+25 flat damage at 25 stacks")
	_assert(elite.get_attack_speed_multiplier() > 1.10, "Attack speed increased at 25 stacks")

	# Add 120 more kills (total 145) -> must clamp at 125 stacks
	for i in range(120):
		elite.add_kill()
	_assert(elite.elite_stacks == 125, "Clamped at 125 maximum stacks")
	_assert(is_equal_approx(elite.get_bonus_damage(), 125.0), "Max +125.0 flat damage cap achieved")
	_assert(is_equal_approx(elite.get_attack_speed_multiplier(), 1.6667), "Max x1.6667 attack speed multiplier achieved")

	# Attack cooldown calculation check
	var base_cd := 0.60
	var eff_cd := elite.get_effective_attack_cooldown(base_cd)
	_assert(is_equal_approx(eff_cd, 0.60 / 1.6667), "Attack cooldown scaled to %.3fs" % eff_cd)

	elite.free()


## Test 2: Tasks 6.3 & 6.4 - Recruitment mineral verification and strict supply cap enforcement
func test_recruitment_and_supply_cap_enforcement() -> void:
	# 1. Permissible recruitment under budget and supply
	var res1 := UnitRecruitmentManager.can_recruit("marine", 500, 10, 80)
	_assert(res1["can_recruit"], "Can recruit marine with 500 minerals at 10/80 supply")

	# 2. Mineral deficit
	var res2 := UnitRecruitmentManager.can_recruit("zealot", 80, 10, 80)
	_assert(not res2["can_recruit"], "Cannot recruit zealot with only 80 minerals (costs 100)")

	# 3. Supply cap reached (80 / 80)
	var res3 := UnitRecruitmentManager.can_recruit("marine", 1000, 80, 80)
	_assert(not res3["can_recruit"], "Cannot recruit when supply is at 80/80 limit")

	# 4. Supply overflow: 79 / 80 trying to recruit 2-supply Zealot
	var res4 := UnitRecruitmentManager.can_recruit("zealot", 1000, 79, 80)
	_assert(not res4["can_recruit"], "Cannot recruit 2-supply unit when only 1 supply space remains")


## Test 3: Task 6.1 - Buy Veterancy promotes unit to Elite status
func test_veterancy_purchase_and_unit_promotion() -> void:
	var unit := BaseUnit3DScript.new()
	var econ := SFEEconomyManager.new()
	econ.current_minerals = 1000

	_assert(not unit._ensure_elite_component().is_elite, "Unit starts non-elite")

	var success := UnitRecruitmentManager.buy_veterancy(unit, econ)
	_assert(success, "Veterancy purchase succeeded")
	_assert(unit.elite_component.is_elite, "Unit is now Elite")
	_assert(econ.current_minerals == 500, "500 minerals deducted for veterancy")

	unit.free()
	econ.free()


## Test 4: Task 6.5 - Vision units with Ace supreme buff become invulnerable
func test_vision_unit_with_ace_invulnerability() -> void:
	var econ := SFEEconomyManager.new()
	econ.current_minerals = 1000

	# Observer recruited with Ace active
	var observer = UnitRecruitmentManager.recruit_unit("observer", Vector3.ZERO, null, econ, 5, 80, true)
	_assert(observer != null, "Observer recruited successfully")
	_assert(observer.is_in_group("vision_units"), "Observer belongs to vision_units group")
	_assert(observer.get_meta("is_invulnerable", false), "Observer with Ace has invulnerability flag")

	observer.free()
	econ.free()


## Test 5: Task 6.8 - Category ring iconography colors
func test_category_ring_styler_colors() -> void:
	var green := CategoryRingStyler.get_category_color("normal")
	_assert(green.g > green.r and green.g > green.b, "Normal ring is green")

	var yellow := CategoryRingStyler.get_category_color("heroic")
	_assert(yellow.r > 0.8 and yellow.g > 0.8, "Heroic ring is yellow")

	var orange := CategoryRingStyler.get_category_color("elite")
	_assert(orange.r > orange.g and orange.g > orange.b, "Elite ring is orange")

	var red := CategoryRingStyler.get_category_color("boss")
	_assert(red.r > 0.8 and red.g < 0.3, "Boss ring is red")
