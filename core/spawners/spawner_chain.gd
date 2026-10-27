class_name SpawnerChain
extends Node

## SpawnerChain - SFE5 Sequential and Branching Spawner Chain Graph (Task 3.2).
## Manages dependency progression: Spawner A -> Spawner B -> Spawner C.
## When predecessor is eradicated, downstream spawners lose invulnerability and become active.

const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const EnemyClassRegistry = preload("res://core/spawners/enemy_class_registry.gd")

# Spawner ID -> SpawnerNode
var spawners: Dictionary = {}

# Spawner ID -> Array[StringName] of prerequisite IDs
var prerequisites: Dictionary = {}

# Set of destroyed spawner IDs
var destroyed_spawners: Dictionary = {}

var class_registry: EnemyClassRegistry = null

signal spawner_registered(spawner: SpawnerNode)
signal spawner_unlocked(spawner: SpawnerNode)
signal spawner_chain_step_completed(spawner_id: StringName, remaining_count: int)
signal all_spawners_destroyed()


func _init() -> void:
	class_registry = EnemyClassRegistry.new()


func set_simulation(sim: Node) -> void:
	if class_registry:
		class_registry.set_simulation(sim)


## Registers a spawner node into the dependency chain.
## If required_spawner_id is empty, it starts ACTIVE; otherwise it starts LOCKED.
func register_spawner(spawner: SpawnerNode, required_spawner_id: StringName = &"") -> void:
	if not spawner:
		return
	
	var sid := spawner.spawner_id
	spawners[sid] = spawner
	
	if not prerequisites.has(sid):
		prerequisites[sid] = []
	
	if required_spawner_id != &"":
		prerequisites[sid].append(required_spawner_id)
		spawner.set_spawner_state(SpawnerNode.State.LOCKED)
	else:
		spawner.set_spawner_state(SpawnerNode.State.ACTIVE)
	
	if not spawner.spawner_destroyed.is_connected(_on_spawner_destroyed):
		spawner.spawner_destroyed.connect(_on_spawner_destroyed)
	
	spawner_registered.emit(spawner)


func add_dependency(child_id: StringName, parent_id: StringName) -> void:
	if not prerequisites.has(child_id):
		prerequisites[child_id] = []
	if not prerequisites[child_id].has(parent_id):
		prerequisites[child_id].append(parent_id)
	
	if spawners.has(child_id):
		var child: SpawnerNode = spawners[child_id]
		if not destroyed_spawners.has(parent_id):
			child.set_spawner_state(SpawnerNode.State.LOCKED)


func _on_spawner_destroyed(sid: StringName, family_name: String) -> void:
	destroyed_spawners[sid] = true
	
	# Task 3.7: Mutate class into Colored Enemy upon spawner destruction
	if class_registry:
		class_registry.mutate_class_on_spawner_destroyed(family_name)
	
	# Check downstream spawners for unlocking
	_evaluate_unlocks()
	
	var remaining := get_remaining_spawner_count()
	spawner_chain_step_completed.emit(sid, remaining)
	
	if remaining <= 0:
		all_spawners_destroyed.emit()


func _evaluate_unlocks() -> void:
	for sid in spawners.keys():
		if destroyed_spawners.has(sid):
			continue
		
		var spawner: SpawnerNode = spawners[sid]
		if spawner.current_state == SpawnerNode.State.LOCKED:
			var reqs: Array = prerequisites.get(sid, [])
			var all_met := true
			for req_id in reqs:
				if not destroyed_spawners.has(req_id):
					all_met = false
					break
			if all_met:
				spawner.unlock()
				spawner_unlocked.emit(spawner)


func get_spawner(sid: StringName) -> SpawnerNode:
	return spawners.get(sid, null)


func get_remaining_spawner_count() -> int:
	var count := 0
	for sid in spawners.keys():
		if not destroyed_spawners.has(sid):
			count += 1
	return count


func get_total_spawner_count() -> int:
	return spawners.size()


func is_all_destroyed() -> bool:
	return get_remaining_spawner_count() == 0 and not spawners.is_empty()
