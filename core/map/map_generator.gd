class_name MapGenerator
extends RefCounted

## MapGenerator - Deterministic Procedural Map & Spawner Network Generator (Tasks 3.12, 3.13, 3.14).
## SFE5 Rules:
## 1. Deterministic by MapSeed.
## 2. Chooses spawner families with progressive threat levels.
## 3. Places spawners with minimum separation rules outside the player base.
## 4. Spawns defensive structures (spores/turrets) around each spawner.
## 5. Constructs and returns a fully wired SpawnerChain.

const MapSeed = preload("res://core/map/map_seed.gd")
const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const SpawnerChain = preload("res://core/spawners/spawner_chain.gd")
const SpawnerFamilyData = preload("res://core/data/spawner_family_data.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")

# Standard map tactical anchor locations (POI) around battle arena
const DEFAULT_SPAWNER_SLOTS: Array[Vector3] = [
	Vector3(25.0, 0.0, 15.0),   # Slot A: Eastern Plain
	Vector3(0.0, 0.0, 32.0),    # Slot B: Northern Ridge
	Vector3(-28.0, 0.0, 22.0),  # Slot C: North-Western Choke
	Vector3(30.0, 0.0, -10.0),  # Slot D: South-Eastern Badlands
	Vector3(-15.0, 0.0, 38.0)   # Slot E: Deep Hive Hollow
]

var map_seed: MapSeed
var available_families: Array[SpawnerFamilyData] = []


func _init(p_seed: MapSeed = null) -> void:
	map_seed = p_seed if p_seed else MapSeed.new()
	_init_default_families()


func _init_default_families() -> void:
	# 1. Zergling Family (Fast horde)
	var zerg := SpawnerFamilyData.new()
	zerg.family_id = &"zergling"
	zerg.family_name = "Nido de Zerglings"
	zerg.archetype_id = 0
	zerg.base_health = 1600.0
	zerg.base_armor = 4.0
	zerg.group_size = 6
	zerg.cycle_seconds = 20.0
	zerg.defensive_structures_count = 2
	available_families.append(zerg)
	
	# 2. Roach Family (Armored frontline)
	var roach := SpawnerFamilyData.new()
	roach.family_id = &"roach"
	roach.family_name = "Madriguera de Cucarachas"
	roach.archetype_id = 1
	roach.base_health = 2200.0
	roach.base_armor = 8.0
	roach.group_size = 4
	roach.cycle_seconds = 20.0
	roach.defensive_structures_count = 2
	available_families.append(roach)
	
	# 3. Hydralisk Family (Ranged artillery)
	var hydra := SpawnerFamilyData.new()
	hydra.family_id = &"hydra"
	hydra.family_name = "Guarida de Hidraliscos"
	hydra.archetype_id = 3
	hydra.base_health = 2600.0
	hydra.base_armor = 6.0
	hydra.group_size = 4
	hydra.cycle_seconds = 20.0
	hydra.defensive_structures_count = 3
	available_families.append(hydra)
	
	# 4. Baneling Family (Explosive assault)
	var bane := SpawnerFamilyData.new()
	bane.family_id = &"baneling"
	bane.family_name = "Cámara de Banelings"
	bane.archetype_id = 2
	bane.base_health = 1900.0
	bane.base_armor = 5.0
	bane.group_size = 5
	bane.cycle_seconds = 20.0
	bane.defensive_structures_count = 2
	available_families.append(bane)


## Generates a pure deterministic layout specification.
## Deterministic: same seed produces exact same plan.
func generate_layout_plan(spawner_count: int = 3) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var count: int = clampi(spawner_count, 1, DEFAULT_SPAWNER_SLOTS.size())
	
	# Shuffle slot indices deterministically
	var slot_indices: Array[int] = []
	for i in range(DEFAULT_SPAWNER_SLOTS.size()):
		slot_indices.append(i)
	
	# Deterministic Fisher-Yates shuffle
	for i in range(slot_indices.size() - 1, 0, -1):
		var j := map_seed.randi_range(0, i)
		var tmp := slot_indices[i]
		slot_indices[i] = slot_indices[j]
		slot_indices[j] = tmp
	
	var prev_id: StringName = &""
	for step in range(count):
		var spawner_id := StringName("spawner_%02d" % (step + 1))
		var slot_idx: int = slot_indices[step]
		var base_pos: Vector3 = DEFAULT_SPAWNER_SLOTS[slot_idx]
		
		# Slight deterministic jitter (within 2m)
		var jitter := Vector3(
			map_seed.randf_range(-1.5, 1.5),
			0.0,
			map_seed.randf_range(-1.5, 1.5)
		)
		var final_pos := base_pos + jitter
		
		# Pick family deterministically based on progression
		var family: SpawnerFamilyData = available_families[step % available_families.size()]
		
		# Generate defense positions around the spawner
		var defenses: Array[Vector3] = []
		var def_count: int = family.defensive_structures_count
		for d in range(def_count):
			var angle := (TAU / float(def_count)) * float(d) + map_seed.randf_range(-0.3, 0.3)
			var dist := map_seed.randf_range(4.5, 6.5)
			var def_pos := final_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			defenses.append(def_pos)
		
		var spawner_spec: Dictionary = {
			"id": spawner_id,
			"family_id": family.family_id,
			"family_name": family.family_name,
			"archetype_id": family.archetype_id,
			"position": final_pos,
			"required_spawner_id": prev_id,
			"health": family.base_health + (float(step) * 400.0),
			"armor": family.base_armor + (float(step) * 1.5),
			"group_size": family.group_size,
			"cycle_seconds": family.cycle_seconds,
			"defenses": defenses
		}
		
		plan.append(spawner_spec)
		prev_id = spawner_id
		
	return plan


## Computes a deterministic MD5/string signature of the layout plan for verification.
func get_layout_signature(plan: Array[Dictionary]) -> String:
	var tokens: PackedStringArray = PackedStringArray()
	for s in plan:
		tokens.append("%s:%s:(%.1f,%.1f):req=%s" % [
			s["id"],
			s["family_id"],
			s["position"].x,
			s["position"].z,
			s["required_spawner_id"]
		])
	return ",".join(tokens)


## Instantiates 3D SpawnerNodes and builds the SpawnerChain.
func spawn_spawner_chain(
	parent_node: Node3D,
	layout_plan: Array[Dictionary],
	budget_manager: EnemyBudgetManager,
	swarm_sim: Node
) -> SpawnerChain:
	var chain := SpawnerChain.new()
	chain.name = "SpawnerChain"
	chain.set_simulation(swarm_sim)
	parent_node.add_child(chain)
	
	for spec in layout_plan:
		var node := SpawnerNode.new()
		node.name = "Spawner_" + str(spec["id"])
		node.spawner_id = spec["id"]
		node.spawner_name = spec["family_name"]
		node.family = spec["family_id"]
		node.archetype_id = spec["archetype_id"]
		node.max_health = spec["health"]
		node.current_health = spec["health"]
		node.structure_armor = spec["armor"]
		node.group_size = spec["group_size"]
		node.cycle_seconds = spec["cycle_seconds"]
		node.budget_manager = budget_manager
		node.swarm_simulation = swarm_sim
		
		parent_node.add_child(node)
		node.global_position = spec["position"]
		
		chain.register_spawner(node, spec["required_spawner_id"])
		
	return chain
