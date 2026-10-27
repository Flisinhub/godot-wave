class_name BossData
extends "res://core/data/unit_data.gd"

## BossData - SFE5 Pinnacle Bosses & Secret Bosses Data Schema.
## Extends UnitData with multi-phase mechanics, summoning rituals, and massive rewards.

@export_group("Ritual & Summoning")
@export_enum("pedestals", "hells_gate", "spawner_chain_complete", "item_sacrifice", "secret_altar") var ritual_type: String = "pedestals"
@export var ritual_description: String = "Solve the 8-pedestal octagram puzzle."

@export_group("Boss Phases & Mechanics")
## Array of dictionaries: [{"hp_threshold": 0.5, "enrage": true, "add_abilities": [...]}]
@export var phases: Array[Dictionary] = []
@export var boss_abilities: Array[Resource] = [] # Array of AbilityData

@export_group("Completion Rewards")
@export var reward_minerals: int = 100000
@export var reward_points: int = 300


func _init() -> void:
	category = "pinnacle_boss"
	category_multiplier = 6.0
	max_health = 12000.0
	attack_damage = 80.0
	attack_cooldown = 1.0
	flat_armor = 15.0
