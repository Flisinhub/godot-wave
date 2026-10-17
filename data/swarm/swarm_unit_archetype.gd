class_name SwarmUnitArchetype
extends Resource

## SwarmUnitArchetype - Defines baseline attributes and visuals for swarm archetypes.
## Used by SwarmSimulation and SwarmRenderer for batch instancing.

@export var archetype_id: int = 0
@export var unit_name: String = "Zergling"
@export var base_hp: float = 35.0
@export var base_speed: float = 7.2
@export var mass: float = 1.0
@export var base_damage: float = 5.0
@export var attack_range: float = 1.6
@export var attack_cooldown: float = 0.5
@export var separation_radius: float = 1.0
@export var armor_level: int = 0
@export var unit_tags: int = 1 # Bitmask (e.g. 1 = LIGHT, 2 = ARMORED, 4 = HEROIC)
@export var body_color: Color = Color(0.25, 0.08, 0.35, 1.0)
@export var accent_color: Color = Color(0.2, 0.95, 0.2, 1.0)
@export var mesh_scale: Vector3 = Vector3(0.8, 0.7, 1.1)
@export var custom_mesh: Mesh = null
@export var custom_material: Material = null
