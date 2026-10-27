class_name DifficultyData
extends Resource

## DifficultyData - SFE5 Difficulty Matrix Schema.
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
@export var base_revive_time_seconds: float = 15.0
@export var revive_time_increment_per_level: float = 1.5
@export var mineral_penalty_on_death: float = 0.0 # Percentage of wallet lost on death
@export var loses_buffs_on_death: bool = false
@export var permadeath: bool = false
