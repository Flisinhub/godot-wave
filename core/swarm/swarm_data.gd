class_name SwarmData
extends RefCounted

## SwarmData - Structure of Arrays (SoA) layout for mass swarm simulation.
## Maintains contiguous typed memory for >1,000 entities to ensure high CPU cache
## utilization and zero per-frame allocation overhead.

const DEFAULT_CAPACITY: int = 4096

# Spatial & Kinematic Arrays
var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
var vel_x: PackedFloat32Array = PackedFloat32Array()
var vel_z: PackedFloat32Array = PackedFloat32Array()
var headings: PackedFloat32Array = PackedFloat32Array()     # Orientation in radians [0, 2*PI]

# Health & Combat Attributes
var current_hp: PackedFloat32Array = PackedFloat32Array()
var max_hp: PackedFloat32Array = PackedFloat32Array()
var attack_damage: PackedFloat32Array = PackedFloat32Array()
var attack_range: PackedFloat32Array = PackedFloat32Array()
var attack_cooldown: PackedFloat32Array = PackedFloat32Array()
var attack_timer: PackedFloat32Array = PackedFloat32Array()
var move_speeds: PackedFloat32Array = PackedFloat32Array()
var armor_levels: PackedInt32Array = PackedInt32Array()

# Unit Classification & Identification
var unit_ids: PackedInt32Array = PackedInt32Array()         # Unique entity identifier
var archetype_ids: PackedInt32Array = PackedInt32Array()    # 0 = Zergling, 1 = Roach, etc.
var unit_tags: PackedInt32Array = PackedInt32Array()        # Bitmask (e.g. 1=LIGHT, 2=ARMORED, 4=HEROIC)
var alive_mask: PackedByteArray = PackedByteArray()         # 1 = Active, 0 = Inactive/Recycled

# Target & State
var target_type: PackedByteArray = PackedByteArray()        # 0 = Follow FlowField, 1 = Unit, 2 = Structure
var target_instance_ids: PackedInt64Array = PackedInt64Array()

# Slot Allocation & Recycling (O(1))
var free_indices: Array[int] = []
var active_count: int = 0
var capacity: int = 0
var next_unit_id: int = 1


func _init(initial_capacity: int = DEFAULT_CAPACITY) -> void:
	init_capacity(initial_capacity)


func init_capacity(cap: int) -> void:
	capacity = cap
	active_count = 0
	next_unit_id = 1
	
	pos_x.resize(capacity)
	pos_x.fill(0.0)
	pos_z.resize(capacity)
	pos_z.fill(0.0)
	vel_x.resize(capacity)
	vel_x.fill(0.0)
	vel_z.resize(capacity)
	vel_z.fill(0.0)
	headings.resize(capacity)
	headings.fill(0.0)
	
	current_hp.resize(capacity)
	current_hp.fill(0.0)
	max_hp.resize(capacity)
	max_hp.fill(0.0)
	attack_damage.resize(capacity)
	attack_damage.fill(0.0)
	attack_range.resize(capacity)
	attack_range.fill(0.0)
	attack_cooldown.resize(capacity)
	attack_cooldown.fill(0.0)
	attack_timer.resize(capacity)
	attack_timer.fill(0.0)
	move_speeds.resize(capacity)
	move_speeds.fill(0.0)
	armor_levels.resize(capacity)
	armor_levels.fill(0)
	
	unit_ids.resize(capacity)
	unit_ids.fill(0)
	archetype_ids.resize(capacity)
	archetype_ids.fill(0)
	unit_tags.resize(capacity)
	unit_tags.fill(0)
	alive_mask.resize(capacity)
	alive_mask.fill(0)
	
	target_type.resize(capacity)
	target_type.fill(0)
	target_instance_ids.resize(capacity)
	target_instance_ids.fill(0)
	
	free_indices.clear()
	free_indices.resize(capacity)
	for i in range(capacity):
		free_indices[i] = capacity - 1 - i


func spawn_unit(
	archetype: int,
	position: Vector3,
	hp: float,
	speed: float,
	dmg: float,
	tags: int = 0,
	rng: float = 1.6,
	cooldown: float = 0.5,
	armor: int = 0
) -> int:
	if free_indices.is_empty():
		return -1
	
	var idx: int = free_indices.pop_back()
	alive_mask[idx] = 1
	
	pos_x[idx] = position.x
	pos_z[idx] = position.z
	vel_x[idx] = 0.0
	vel_z[idx] = 0.0
	headings[idx] = 0.0
	
	current_hp[idx] = hp
	max_hp[idx] = hp
	attack_damage[idx] = dmg
	attack_range[idx] = rng
	attack_cooldown[idx] = cooldown
	attack_timer[idx] = 0.0
	move_speeds[idx] = speed
	armor_levels[idx] = armor
	
	archetype_ids[idx] = archetype
	unit_tags[idx] = tags
	unit_ids[idx] = next_unit_id
	next_unit_id += 1
	
	target_type[idx] = 0
	target_instance_ids[idx] = 0
	
	active_count += 1
	return idx


func despawn_unit(idx: int) -> void:
	if idx < 0 or idx >= capacity or alive_mask[idx] == 0:
		return
	
	alive_mask[idx] = 0
	vel_x[idx] = 0.0
	vel_z[idx] = 0.0
	current_hp[idx] = 0.0
	
	free_indices.push_back(idx)
	active_count -= 1


func is_alive(idx: int) -> bool:
	if idx < 0 or idx >= capacity:
		return false
	return alive_mask[idx] == 1


func get_position_3d(idx: int) -> Vector3:
	return Vector3(pos_x[idx], 0.0, pos_z[idx])


func set_position_3d(idx: int, pos: Vector3) -> void:
	pos_x[idx] = pos.x
	pos_z[idx] = pos.z


func get_position_2d(idx: int) -> Vector2:
	return Vector2(pos_x[idx], pos_z[idx])


func set_position_2d(idx: int, pos: Vector2) -> void:
	pos_x[idx] = pos.x
	pos_z[idx] = pos.y


func get_velocity_2d(idx: int) -> Vector2:
	return Vector2(vel_x[idx], vel_z[idx])


func set_velocity_2d(idx: int, vel: Vector2) -> void:
	vel_x[idx] = vel.x
	vel_z[idx] = vel.y


func apply_damage(idx: int, amount: float) -> bool:
	if not is_alive(idx):
		return false
	
	current_hp[idx] = max(0.0, current_hp[idx] - amount)
	if current_hp[idx] <= 0.0:
		despawn_unit(idx)
		return true # Unit died
	return false


func get_active_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(active_count)
	var cursor: int = 0
	for i in range(capacity):
		if alive_mask[i] == 1:
			result[cursor] = i
			cursor += 1
			if cursor >= active_count:
				break
	return result


func clear_all() -> void:
	init_capacity(capacity)
