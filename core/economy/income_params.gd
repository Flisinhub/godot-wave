class_name IncomeParams
extends RefCounted

## IncomeParams - Input parameters for SFE5 Master Income Formula.
## Encapsulates all physical and categoric properties of an eliminated unit.

var base_health: float = 35.0
var base_shield: float = 0.0
var health_mult: float = 1.0

var weapon_damage: float = 5.0
var damage_mult: float = 1.0
var attack_period: float = 0.7
var has_weapon: bool = true

var max_energy: float = 0.0
var category: String = "normal" # "normal", "structure", "heroic", "elite", "map_boss", "summoned_boss", "pinnacle_boss"
var category_multiplier: float = 1.0

var player_count: int = 1
var split_income: bool = false
var pedestal_bonus: float = 0.0
var difficulty_mult: float = 1.0


func _init(
	p_hp: float = 35.0,
	p_dmg: float = 5.0,
	p_period: float = 0.7,
	p_category: String = "normal",
	p_category_mult: float = 1.0,
	p_players: int = 1,
	p_diff_mult: float = 1.0
) -> void:
	base_health = p_hp
	weapon_damage = p_dmg
	attack_period = p_period
	category = p_category
	category_multiplier = p_category_mult
	player_count = p_players
	difficulty_mult = p_diff_mult
