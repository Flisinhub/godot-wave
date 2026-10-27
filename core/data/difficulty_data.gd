class_name DifficultyData
extends Resource

## DifficultyData - SFE5 Difficulty Matrix Schema (Task 7.1).
## Defines the precise economic, revival, and punishment scaling per tier.

@export_group("Identity")
@export_range(0, 6) var tier: int = 1
@export var difficulty_name: String = "Normal"
@export var badge_color: Color = Color(0.35, 0.85, 1.0)

@export_group("Multipliers")
@export var income_multiplier: float = 1.0
@export var enemy_stat_multiplier: float = 1.0
@export var hive_evolution_cadence: float = 120.0

@export_group("Revival & Penalty Rules")
@export var base_revive_time_seconds: float = 20.0
@export var revive_time_increment_per_level: float = 0.4
@export var mineral_penalty_on_death: float = 0.25 # Fraction of minerals lost on death
@export var buff_cost_retention: float = 0.25 # Fraction of buff cost retained / lost
@export var loses_buffs_on_death: bool = true
@export var permadeath: bool = false


## Calculates total revival countdown in seconds for a hero of `hero_level`
func calculate_revive_time(hero_level: int) -> float:
	return base_revive_time_seconds + (float(maxi(1, hero_level)) * revive_time_increment_per_level)


## Computes the mineral loss when dying with `current_minerals`
func calculate_mineral_penalty(current_minerals: int) -> int:
	return int(float(current_minerals) * mineral_penalty_on_death)
