class_name SpawnerFamilyData
extends Resource

## SpawnerFamilyData - SFE5 Spawner Family Archetype Schema (Task 3.11).
## Defines families of spawners (Zergling, Roach, Hydra, etc.) used by MapGenerator.

@export var family_id: StringName = &"zergling"
@export var family_name: String = "Nido de Zerglings"
@export var archetype_id: int = 0
@export var base_health: float = 1600.0
@export var base_armor: float = 5.0
@export var group_size: int = 6
@export var cycle_seconds: float = 20.0
@export var defensive_structures_count: int = 2
@export var colored_buff_names: Array[String] = ["speed_boost", "damage_boost"]
