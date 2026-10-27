class_name EnemyClassRegistry
extends RefCounted

## EnemyClassRegistry - SFE5 Enemy Class Buff & Colored Enemies System (Tasks 3.6 & 3.7).
## SFE5 Rule: When a spawner of an enemy class (e.g. Zerglings) is destroyed,
## remaining and future units of that class gain permanent randomized buffs
## (jump in stats and bright colored shader/material tint).

signal class_mutated(target_class: String, tier: int, color: Color, hp_mult: float, dmg_mult: float, speed_mult: float)

# Archetype mapping to known SFE5 classes
const CLASS_TO_ARCHETYPE_ID: Dictionary = {
	"zergling": 0,
	"roach": 1,
	"baneling": 2,
	"hydra": 3,
	"hydralisk": 3,
	"ultralisk": 4
}

# Mutation color palette per tier
const MUTATION_PALETTE: Array[Color] = [
	Color(0.2, 0.95, 1.0),   # Tier 1: Neon Cyan
	Color(1.0, 0.25, 0.15),  # Tier 2: Fiery Crimson
	Color(0.2, 1.0, 0.35),   # Tier 3: Toxic Emerald
	Color(0.85, 0.2, 1.0),   # Tier 4: Psionic Violet
	Color(1.0, 0.82, 0.1)    # Tier 5: Radiant Gold
]

# Tracked state per class: class_name -> Dictionary
# { "tier": int, "hp_mult": float, "dmg_mult": float, "speed_mult": float, "color": Color }
var classes: Dictionary = {}
var swarm_simulation: Node = null


func _init() -> void:
	_init_default_classes()


func _init_default_classes() -> void:
	for c_name in ["zergling", "roach", "baneling", "hydra", "ultralisk"]:
		classes[c_name] = {
			"tier": 0,
			"hp_mult": 1.0,
			"dmg_mult": 1.0,
			"speed_mult": 1.0,
			"armor_bonus": 0,
			"color": Color(1.0, 1.0, 1.0)
		}


func set_simulation(sim: Node) -> void:
	swarm_simulation = sim


func get_class_info(target_class: String) -> Dictionary:
	var key := target_class.to_lower()
	if classes.has(key):
		return classes[key]
	return {
		"tier": 0,
		"hp_mult": 1.0,
		"dmg_mult": 1.0,
		"speed_mult": 1.0,
		"armor_bonus": 0,
		"color": Color.WHITE
	}


## Called when a spawner of a specific class is destroyed.
## Permanently evolves this class into a "Colored Enemy" with boosted stats and shader tint.
func mutate_class_on_spawner_destroyed(target_class: String) -> Dictionary:
	var key := target_class.to_lower()
	if not classes.has(key):
		classes[key] = {
			"tier": 0,
			"hp_mult": 1.0,
			"dmg_mult": 1.0,
			"speed_mult": 1.0,
			"armor_bonus": 0,
			"color": Color.WHITE
		}
	
	var info: Dictionary = classes[key]
	info["tier"] += 1
	var current_tier: int = info["tier"]
	
	# Stat leaps (SFE5 Wiki rule: jump in HP, damage, and speed)
	info["hp_mult"] += 0.45
	info["dmg_mult"] += 0.35
	info["speed_mult"] += 0.15
	info["armor_bonus"] += 2
	
	# Choose palette color based on tier
	var palette_idx := (current_tier - 1) % MUTATION_PALETTE.size()
	var new_color: Color = MUTATION_PALETTE[palette_idx]
	info["color"] = new_color
	
	# Propagate to SwarmSimulation & SwarmRenderer if available
	_apply_mutation_to_simulation(key, info)
	
	class_mutated.emit(key, current_tier, new_color, info["hp_mult"], info["dmg_mult"], info["speed_mult"])
	return info


func _apply_mutation_to_simulation(target_class: String, info: Dictionary) -> void:
	if not swarm_simulation or not is_instance_valid(swarm_simulation):
		return
	
	var arch_id: int = CLASS_TO_ARCHETYPE_ID.get(target_class, -1)
	if arch_id < 0:
		return
	
	# Update archetype stats in SwarmSimulation
	if "archetype_defs" in swarm_simulation:
		var arch_defs: Dictionary = swarm_simulation.archetype_defs
		if arch_defs.has(arch_id):
			var arch = arch_defs[arch_id]
			if arch:
				arch.base_hp = arch.base_hp * 1.45
				arch.base_damage = arch.base_damage * 1.35
				arch.base_speed = arch.base_speed * 1.15
				arch.armor_level += 2
	
	# Tint MultiMesh material in SwarmRenderer
	if "renderer" in swarm_simulation:
		var r = swarm_simulation.renderer
		if r and is_instance_valid(r) and "multimesh_instances" in r:
			var mm_instances: Dictionary = r.multimesh_instances
			if mm_instances.has(arch_id):
				var mmi = mm_instances[arch_id]
				if mmi and mmi.material_override:
					var mat: Material = mmi.material_override
					if mat is StandardMaterial3D:
						var dup_mat: StandardMaterial3D = mat.duplicate()
						dup_mat.albedo_color = info["color"]
						dup_mat.emission_enabled = true
						dup_mat.emission = info["color"] * 0.4
						mmi.material_override = dup_mat
					elif mat is ShaderMaterial:
						var dup_sh: ShaderMaterial = mat.duplicate()
						dup_sh.set_shader_parameter("tint_color", info["color"])
						dup_sh.set_shader_parameter("glow_color", info["color"])
						mmi.material_override = dup_sh
