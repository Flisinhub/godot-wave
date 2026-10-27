class_name SpawnerData
extends Resource

## SpawnerData - SFE5 Spawner Node & Spawner Chain Specification Schema.
## Defines the spawning cadence (20s), units produced, prerequisites, and colored buffs.

@export_group("Identity & Chain Graph")
@export var id: StringName = &"spawner_01"
@export var spawner_name: String = "Zergling Spawner"
@export var family: String = "zergling" # "zergling", "roach", "hydra", "baneling", "ultralisk"
@export var level: int = 1
@export var required_spawner_id: StringName = &"" # Prerequisite spawner that must die to unlock this one

@export_group("Production & Horde Cycle")
@export var spawn_units: Array[Resource] = [] # Array of UnitData or SwarmUnitArchetype
@export var group_size: int = 6
@export var cycle_seconds: float = 20.0
@export var max_living_budget: int = 300

@export_group("Destruction Rewards & Colored Buffs")
@export var buffs_on_destroyed: Array[String] = ["speed_boost", "damage_boost"]
@export var mineral_reward: int = 250

@export_group("Physical Structure Attributes")
@export var structure_health: float = 1500.0
@export var structure_armor: float = 5.0
@export var spawner_scene: PackedScene = null
