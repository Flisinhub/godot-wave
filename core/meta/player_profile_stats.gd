class_name PlayerProfileStats
extends RefCounted

## PlayerProfileStats - SFE5 Career Statistics & Lifetime Progression (Task 12.10).
## Tracks lifetime games, win rate, mineral accumulations, and highest difficulty conquests.

const BankManager = preload("res://core/persistence/bank_manager.gd")

var games_played: int = 0
var victories: int = 0
var defeats: int = 0
var total_minerals_mined: int = 0
var enemies_slain: int = 0
var bosses_defeated: int = 0
var pedestals_solved: int = 0
var highest_difficulty_won: int = 0


func _init() -> void:
	load_from_bank()


func get_win_rate() -> float:
	if games_played <= 0:
		return 0.0
	return float(victories) / float(games_played)


func record_game_finished(is_victory: bool, diff_tier: int, minerals_gained: int, kills: int, bosses: int, pedestals: int) -> void:
	games_played += 1
	if is_victory:
		victories += 1
		highest_difficulty_won = maxi(highest_difficulty_won, diff_tier)
	else:
		defeats += 1

	total_minerals_mined += minerals_gained
	enemies_slain += kills
	bosses_defeated += bosses
	pedestals_solved += pedestals

	save_to_bank()


func to_dictionary() -> Dictionary:
	return {
		"games_played": games_played,
		"victories": victories,
		"defeats": defeats,
		"total_minerals_mined": total_minerals_mined,
		"enemies_slain": enemies_slain,
		"bosses_defeated": bosses_defeated,
		"pedestals_solved": pedestals_solved,
		"highest_difficulty_won": highest_difficulty_won
	}


func from_dictionary(dict: Dictionary) -> void:
	games_played = int(dict.get("games_played", 0))
	victories = int(dict.get("victories", 0))
	defeats = int(dict.get("defeats", 0))
	total_minerals_mined = int(dict.get("total_minerals_mined", 0))
	enemies_slain = int(dict.get("enemies_slain", 0))
	bosses_defeated = int(dict.get("bosses_defeated", 0))
	pedestals_solved = int(dict.get("pedestals_solved", 0))
	highest_difficulty_won = int(dict.get("highest_difficulty_won", 0))


func save_to_bank() -> void:
	var bank: Dictionary = BankManager.load_bank()
	bank["lifetime_stats"] = to_dictionary()
	BankManager.save_bank(bank)


func load_from_bank() -> void:
	var bank: Dictionary = BankManager.load_bank()
	if bank.has("lifetime_stats") and bank["lifetime_stats"] is Dictionary:
		from_dictionary(bank["lifetime_stats"])
