class_name UpgradeData
extends Resource

## UpgradeData - SFE5 Racial & Attribute Upgrades Schema.
## Defines incremental progression upgrades (damage, armor, health, energy, attack speed).

@export_group("Identity")
@export var id: StringName = &"upgrade"
@export var upgrade_name: String = "Upgrade"
@export_enum("damage", "armor", "health", "energy", "attack_speed") var category: String = "damage"
@export_enum("terran", "zerg", "protoss", "generic") var race: String = "terran"
@export var icon_path: String = ""
@export_multiline var description: String = ""

@export_group("Levels & Cost")
@export var current_level: int = 0
@export var max_level: int = 50
@export var base_cost: int = 100
@export var cost_growth_multiplier: float = 1.15

@export_group("Stat Modifier per Level")
@export var flat_effect_per_level: float = 2.0
@export var multiplier_effect_per_level: float = 0.05


## Calculates mineral purchase cost for the next upgrade level.
func get_cost_for_level(target_level: int) -> int:
	if target_level <= 1:
		return base_cost
	return int(round(float(base_cost) * pow(cost_growth_multiplier, float(target_level - 1))))


## Calculates total accumulated bonus for a given level.
func get_total_flat_bonus(level: int) -> float:
	return float(level) * flat_effect_per_level


func get_total_multiplier_bonus(level: int) -> float:
	return float(level) * multiplier_effect_per_level
