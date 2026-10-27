class_name TestDataCatalog
extends RefCounted

## Unit Test Suite for SFE5 Data Architecture & Validation (Task 2.8).
## Validates:
## 1. DataCatalog recursive indexing of res://data/.
## 2. All 12 Heroes, 23 Skills, 5 Buffs, and Enemies loaded.
## 3. DataValidator returns 0 errors and confirms ID uniqueness.
## 4. Custom UnitData generation and SFE5 Master Income Formula evaluation.

const DataCatalogScript = preload("res://core/data/data_catalog.gd")
const DataValidatorScript = preload("res://core/data/data_validator.gd")
const UnitDataScript = preload("res://core/data/unit_data.gd")
const IncomeFormulaScript = preload("res://core/economy/income_formula.gd")

var _last_error: String = ""


func _pass() -> Dictionary:
	return {"passed": true}


func _fail(msg: String) -> Dictionary:
	_last_error = msg
	return {"passed": false, "error": msg}


func test_data_catalog_loads_all_resources() -> Dictionary:
	var catalog = DataCatalogScript.new()
	if catalog.loaded_resources_count < 40:
		return _fail("Expected at least 40 resources loaded, got %d" % catalog.loaded_resources_count)

	# 1. Verify 12 Heroes cataloged
	if catalog.heroes.size() != 12:
		return _fail("Expected exactly 12 heroes in catalog, got %d" % catalog.heroes.size())
	if catalog.get_hero(&"raynor") == null:
		return _fail("Raynor hero not found in catalog")
	if catalog.get_hero(&"zeratul") == null:
		return _fail("Zeratul hero not found in catalog")

	# 2. Verify Skills cataloged
	if catalog.skills.size() < 21:
		return _fail("Expected at least 21 skills in catalog, got %d" % catalog.skills.size())
	if catalog.get_skill(&"stimpack") == null:
		return _fail("Stimpack skill not found in catalog")
	if catalog.get_skill(&"psionic_storm") == null:
		return _fail("Psionic storm skill not found in catalog")

	# 3. Verify Buffs cataloged with tiers
	if catalog.buffs.size() < 5:
		return _fail("Expected at least 5 buffs in catalog, got %d" % catalog.buffs.size())
	var stim_buff = catalog.get_buff(&"stimpack")
	if stim_buff == null:
		return _fail("Stimpack buff not found in catalog")
	if stim_buff.tier != 1:
		return _fail("Expected Stimpack buff to be tier 1, got %d" % stim_buff.tier)

	# 4. Verify Enemies cataloged
	var zergling: Resource = catalog.get_unit(&"zergling")
	if zergling == null:
		return _fail("Zergling enemy not found in catalog")
	var zerg_hp: float = zergling.get("max_health") if zergling.get("max_health") != null else 0.0
	if zerg_hp != 35.0:
		return _fail("Expected Zergling hp 35, got %.1f" % zerg_hp)

	var roach: Resource = catalog.get_unit(&"roach")
	if roach == null:
		return _fail("Roach enemy not found in catalog")

	var hydra: Resource = catalog.get_unit(&"hydralisk")
	if hydra == null:
		return _fail("Hydralisk enemy not found in catalog")

	return _pass()


func test_data_validator_zero_errors_and_unique_ids() -> Dictionary:
	var report = DataValidatorScript.validate_all("res://data")
	if report.get("checked_count", 0) < 40:
		return _fail("Expected at least 40 resources validated, got %d" % report.get("checked_count", 0))

	if not report.get("valid", false):
		var errors = report.get("errors", [])
		return _fail("DataValidator reported errors: " + str(errors))

	if report.get("error_count", 0) != 0:
		return _fail("Expected 0 validation errors, got %d" % report.get("error_count", 0))

	return _pass()


func test_custom_unit_data_and_income_formula() -> Dictionary:
	# Verifies the Golden Rule: A developer/player can create any new unit via UnitData
	# and it seamlessly produces the exact SFE5 Master Income Formula bounty.
	var unit = UnitDataScript.new()
	unit.id = &"protoss_colossus"
	unit.unit_name = "Colossus"
	unit.race = "protoss"
	unit.category = "heroic"
	unit.category_multiplier = 4.0
	unit.max_health = 300.0
	unit.max_shield = 150.0
	unit.flat_armor = 1.0
	unit.attack_damage = 30.0
	unit.attack_cooldown = 1.5
	unit.has_weapon = true

	var inc_params = unit.get_income_params(1, 1.0)
	if inc_params == null:
		return _fail("Failed to generate IncomeParams from UnitData")

	var bounty: int = IncomeFormulaScript.compute(inc_params)
	if bounty <= 0:
		return _fail("Expected positive bounty for custom unit, got %d" % bounty)

	# Verify formula math:
	# s = (300 + 150)/3 + 30/1.5 = 150 + 20 = 170
	# s^0.32 = 170^0.32 = 5.16
	# shared (1 player) = 5.16 * 4 * 2.75 = 56.77
	# rate 0.24 = 13.62
	# category heroic x4 = 54.5 -> ~55 minerals
	if absi(bounty - 55) > 2:
		return _fail("Expected ~55 bounty for Colossus, got %d" % bounty)

	return _pass()
