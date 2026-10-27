class_name EnemyData
extends "res://core/data/unit_data.gd"

## EnemyData - Defines attributes, combat statistics, and visual styling for swarm units.
## Extends UnitData per SFE5 Data Architecture specification.

@export var enemy_name: String = "Zergling":
	get:
		return unit_name if unit_name != "Unit" and unit_name != "" else enemy_name
	set(val):
		enemy_name = val
		unit_name = val

@export var kill_reward: int = 5
@export var body_color: Color = Color(0.25, 0.08, 0.35)
@export var accent_color: Color = Color(0.2, 0.95, 0.2)


func _init() -> void:
	race = "zerg"
	category = "normal"
	category_multiplier = 1.0
