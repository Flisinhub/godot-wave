class_name MapSeed
extends RefCounted

## MapSeed - SFE5 Deterministic Seed Management (Task 3.10).
## Guarantees identical map spawner layouts, family selections, and puzzle orders
## when given the same seed.

var raw_seed: Variant = 0
var numeric_seed: int = 0
var rng: RandomNumberGenerator = null


func _init(p_seed: Variant = null) -> void:
	if p_seed == null:
		# Generate a random 6-digit seed if none provided
		var sys_rng := RandomNumberGenerator.new()
		sys_rng.randomize()
		p_seed = sys_rng.randi_range(100000, 999999)
	
	set_seed(p_seed)


func set_seed(p_seed: Variant) -> void:
	raw_seed = p_seed
	if p_seed is int:
		numeric_seed = p_seed
	elif p_seed is String:
		numeric_seed = p_seed.hash()
	else:
		numeric_seed = str(p_seed).hash()
	
	rng = RandomNumberGenerator.new()
	rng.seed = numeric_seed


func get_seed_string() -> String:
	return str(raw_seed)


func randf() -> float:
	return rng.randf()


func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)


func pick_random(array: Array) -> Variant:
	if array.is_empty():
		return null
	var idx := rng.randi_range(0, array.size() - 1)
	return array[idx]
