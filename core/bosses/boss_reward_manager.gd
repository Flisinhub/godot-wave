class_name BossRewardManager
extends RefCounted

## BossRewardManager - SFE5 Pinnacle Boss Victory Processing (Tasks 10.4, 10.18, 10.19).
## Handles awarding 100,000 minerals, 300 rank points saved to BankManager,
## and unlocking secret units permanently in Torment difficulty or temporarily in standard modes.

const BankManager = preload("res://core/persistence/bank_manager.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")

const PINNACLE_MINERAL_REWARD: int = 100000
const PINNACLE_RANK_POINTS: int = 300


## Processes victory rewards for defeating a Pinnacle Boss.
## Returns summary of granted benefits.
static func process_pinnacle_victory(boss_id: StringName, economy_manager: SFEEconomyManager = null, difficulty_tier: int = 1, unlocked_unit: StringName = &"") -> Dictionary:
	var minerals_awarded: int = PINNACLE_MINERAL_REWARD
	var rank_awarded: int = PINNACLE_RANK_POINTS

	# 1. Grant in-game match minerals
	if economy_manager != null:
		economy_manager.add_minerals(minerals_awarded, "Pinnacle Boss Defeated: %s" % boss_id)

	# 2. Update persistent bank
	var bank: Dictionary = BankManager.load_bank()
	var current_rank: int = bank.get("rank_points", 0)
	bank["rank_points"] = current_rank + rank_awarded

	# Track bosses defeated
	var defeated_list: Array = bank.get("pinnacle_bosses_defeated", [])
	if not defeated_list.has(str(boss_id)):
		defeated_list.append(str(boss_id))
	bank["pinnacle_bosses_defeated"] = defeated_list

	# 3. Secret Unit Unlock (Task 10.18)
	# Permanent if difficulty >= Torment (tier 4), else session only
	var is_permanent: bool = difficulty_tier >= 4
	if unlocked_unit != &"" and is_permanent:
		var secret_units: Array = bank.get("unlocked_secret_units", [])
		if not secret_units.has(str(unlocked_unit)):
			secret_units.append(str(unlocked_unit))
		bank["unlocked_secret_units"] = secret_units

	BankManager.save_bank(bank)

	return {
		"boss_id": boss_id,
		"minerals": minerals_awarded,
		"rank_points": rank_awarded,
		"total_rank": bank["rank_points"],
		"secret_unit": unlocked_unit,
		"is_permanent_unlock": is_permanent
	}


## Returns the category multiplier for income calculation (Task 10.19):
## Summoned Boss (x2), Pinnacle Boss (x6).
static func get_boss_category_multiplier(is_pinnacle_main: bool) -> float:
	return 6.0 if is_pinnacle_main else 2.0
