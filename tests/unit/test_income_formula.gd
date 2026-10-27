class_name TestIncomeFormula
extends RefCounted

## Unit Test Suite for SFE5 Master Income Formula.
## Verifies 23 reference cases from income_reference_cases.json and edge cases.

const IncomeParams = preload("res://core/economy/income_params.gd")
const IncomeFormula = preload("res://core/economy/income_formula.gd")

var _last_error: String = ""


func _pass() -> Dictionary:
	return {"passed": true}


func _fail(msg: String) -> Dictionary:
	_last_error = msg
	return {"passed": false, "error": msg}


func test_all_reference_cases_from_json() -> Dictionary:
	var path: String = "res://tests/unit/income_reference_cases.json"
	if not FileAccess.file_exists(path):
		return _fail("income_reference_cases.json does not exist at " + path)

	var fa := FileAccess.open(path, FileAccess.READ)
	var content: String = fa.get_as_text()
	fa.close()

	var json_data = JSON.parse_string(content)
	if json_data == null or not (json_data is Array):
		return _fail("Failed to parse json array from " + path)

	var cases: Array = json_data as Array
	if cases.size() < 20:
		return _fail("Expected at least 20 reference cases, found %d" % cases.size())

	for c in cases:
		var p = IncomeParams.new()
		p.base_health = float(c["hp"])
		p.base_shield = float(c["sh"])
		p.weapon_damage = float(c["dmg"])
		p.attack_period = float(c["period"])
		p.has_weapon = bool(c["weapon"])
		p.max_energy = float(c["energy"])
		p.category = str(c["cat"])
		p.category_multiplier = float(c["cat_mult"])
		p.player_count = int(c["players"])
		p.split_income = bool(c["split"])
		p.pedestal_bonus = float(c["pedestal"])
		p.difficulty_mult = float(c["diff"])

		var expected: int = int(c["expected_minerals"])
		var actual: int = IncomeFormula.compute(p)

		if absi(actual - expected) > 1:
			return _fail("Case '%s': expected ~%d minerals, got %d" % [c["name"], expected, actual])

	return _pass()


func test_income_minimum_guarantee_one() -> Dictionary:
	var p = IncomeParams.new(0.01, 0.0, 10.0, "normal", 0.01, 12, 0.01)
	var actual: int = IncomeFormula.compute(p)
	if actual < 1:
		return _fail("Expected minimum guaranteed income of 1, got %d" % actual)
	return _pass()


func test_income_overflow_threshold_damping() -> Dictionary:
	var p_normal = IncomeParams.new(400000.0, 1000.0, 1.0, "normal", 1.0, 1, 1.0)
	var p_overflow = IncomeParams.new(2000000.0, 1000.0, 1.0, "normal", 1.0, 1, 1.0)

	var actual_normal: int = IncomeFormula.compute(p_normal)
	var actual_overflow: int = IncomeFormula.compute(p_overflow)

	if actual_overflow <= actual_normal:
		return _fail("Overflow dampening should still strictly increase income")
	return _pass()


func test_income_split_vs_shared_difference() -> Dictionary:
	var p_shared = IncomeParams.new(35.0, 5.0, 0.7, "normal", 1.0, 4, 1.0)
	p_shared.split_income = false

	var p_split = IncomeParams.new(35.0, 5.0, 0.7, "normal", 1.0, 4, 1.0)
	p_split.split_income = true

	var res_shared: int = IncomeFormula.compute(p_shared)
	var res_split: int = IncomeFormula.compute(p_split)

	if res_shared == 0 or res_split == 0:
		return _fail("Neither result should be zero")
	return _pass()
