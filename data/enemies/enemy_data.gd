class_name EnemyData
extends Resource

## EnemyData - Defines attributes, combat statistics, and visual styling for swarm units.

@export var enemy_name: String = "Zergling"
@export var max_health: float = 35.0
@export var move_speed: float = 7.2
@export var attack_damage: float = 5.0
@export var attack_range: float = 1.6
@export var attack_cooldown: float = 0.5
@export var kill_reward: int = 5
@export var body_color: Color = Color(0.25, 0.08, 0.35)
@export var accent_color: Color = Color(0.2, 0.95, 0.2)
@export var mesh_scale: Vector3 = Vector3(0.8, 0.7, 1.1)
