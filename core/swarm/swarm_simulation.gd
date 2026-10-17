class_name SwarmSimulation
extends Node3D

## SwarmSimulation - Main coordinator for mass swarm simulation.
## Orchestrates SoA Data (SwarmData), Spatial Hashing (SwarmSpatialHash),
## 3-Phase Flow Field (SwarmFlowField), and Batch Rendering (SwarmRenderer).

@export var max_units: int = 4096
@export var map_bounds_min: Vector2 = Vector2(-64.0, -64.0)
@export var map_bounds_max: Vector2 = Vector2(64.0, 64.0)
@export var flow_weight: float = 1.0
@export var separation_weight: float = 1.4
@export var default_separation_radius: float = 0.9
@export var acceleration: float = 18.0
@export var turn_speed: float = 12.0
@export var auto_sync_structures: bool = true

var swarm_data: SwarmData
var spatial_hash: SwarmSpatialHash
var flow_field: SwarmFlowField
var renderer: SwarmRenderer

var archetype_defs: Dictionary = {} # archetype_id -> SwarmUnitArchetype
var _cached_sep_radius: PackedFloat32Array = PackedFloat32Array()
var _cached_mass: PackedFloat32Array = PackedFloat32Array()
var _cached_speed: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	init_subsystems()
	_update_cached_archetype_arrays()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if renderer and renderer.get_parent() != self:
			renderer.free()
			renderer = null


func _ready() -> void:
	# Attach or ensure renderer exists in scene tree
	if not renderer:
		renderer = SwarmRenderer.new()
		renderer.name = "SwarmRenderer"
		add_child(renderer)
	elif renderer.get_parent() == null:
		add_child(renderer)
	
	_load_archetype_resources()
	
	if auto_sync_structures:
		_connect_signal_bus()
		_discover_scene_structures()


func init_subsystems() -> void:
	if not swarm_data or swarm_data.capacity != max_units:
		swarm_data = SwarmData.new(max_units)
	
	var grid_w := int(ceil(map_bounds_max.x - map_bounds_min.x))
	var grid_h := int(ceil(map_bounds_max.y - map_bounds_min.y))
	
	if not spatial_hash:
		spatial_hash = SwarmSpatialHash.new(map_bounds_min, map_bounds_max, 1.2, max_units)
	else:
		spatial_hash.setup(map_bounds_min, map_bounds_max, 1.2, max_units)
	
	if not flow_field:
		flow_field = SwarmFlowField.new(grid_w, grid_h, 1.0, map_bounds_min)
	else:
		flow_field.setup(grid_w, grid_h, 1.0, map_bounds_min)


func setup_simulation(min_bounds: Vector2, max_bounds: Vector2, capacity: int) -> void:
	max_units = capacity
	map_bounds_min = min_bounds
	map_bounds_max = max_bounds
	
	if not swarm_data or swarm_data.capacity != capacity:
		swarm_data = SwarmData.new(capacity)
	
	var grid_w := int(ceil(map_bounds_max.x - map_bounds_min.x))
	var grid_h := int(ceil(map_bounds_max.y - map_bounds_min.y))
	
	if not spatial_hash:
		spatial_hash = SwarmSpatialHash.new(map_bounds_min, map_bounds_max, 1.2, capacity)
	else:
		spatial_hash.setup(map_bounds_min, map_bounds_max, 1.2, capacity)
	
	if not flow_field:
		flow_field = SwarmFlowField.new(grid_w, grid_h, 1.0, map_bounds_min)
	else:
		flow_field.setup(grid_w, grid_h, 1.0, map_bounds_min)


func _load_archetype_resources() -> void:
	var zerg_path := "res://data/swarm/zergling_archetype.tres"
	if ResourceLoader.exists(zerg_path):
		var zerg: SwarmUnitArchetype = load(zerg_path) as SwarmUnitArchetype
		if zerg:
			register_archetype(zerg)
	
	var roach_path := "res://data/swarm/roach_archetype.tres"
	if ResourceLoader.exists(roach_path):
		var roach: SwarmUnitArchetype = load(roach_path) as SwarmUnitArchetype
		if roach:
			register_archetype(roach)


func register_archetype(archetype: SwarmUnitArchetype) -> void:
	archetype_defs[archetype.archetype_id] = archetype
	_update_cached_archetype_arrays()
	if renderer:
		renderer.register_archetype(archetype.archetype_id, archetype)


func _update_cached_archetype_arrays() -> void:
	var max_id: int = 0
	for aid in archetype_defs.keys():
		max_id = maxi(max_id, int(aid))
	var sz: int = maxi(64, max_id + 1)
	if _cached_sep_radius.size() < sz:
		_cached_sep_radius.resize(sz)
		_cached_mass.resize(sz)
		_cached_speed.resize(sz)
	_cached_sep_radius.fill(default_separation_radius)
	_cached_mass.fill(1.0)
	_cached_speed.fill(7.2)
	for aid in archetype_defs.keys():
		var a: SwarmUnitArchetype = archetype_defs[aid]
		var idx: int = int(aid)
		_cached_sep_radius[idx] = a.separation_radius
		_cached_mass[idx] = a.mass
		_cached_speed[idx] = a.base_speed


func _connect_signal_bus() -> void:
	var tree := get_tree()
	if not tree or not tree.root:
		return
	
	var bus: Node = tree.root.get_node_or_null("SignalBus")
	if bus:
		if bus.has_signal("gate_state_changed") and not bus.gate_state_changed.is_connected(_on_gate_state_changed):
			bus.gate_state_changed.connect(_on_gate_state_changed)
		if bus.has_signal("structure_destroyed") and not bus.structure_destroyed.is_connected(_on_structure_destroyed):
			bus.structure_destroyed.connect(_on_structure_destroyed)


func _discover_scene_structures() -> void:
	var tree := get_tree()
	if not tree:
		return
	
	# Register base objectives (CommandCenter) as permanent goals
	var command_centers := tree.get_nodes_in_group("command_centers")
	for cc in command_centers:
		if cc is Node3D:
			register_goal(cc.global_position)
			register_structure_node(cc, 4.0, true)
	
	# Discover generic structures
	var structures := tree.get_nodes_in_group("structures")
	for s in structures:
		if s is Node3D:
			if s.is_in_group("command_centers") or s.name.to_lower().contains("command"):
				register_goal(s.global_position)
				register_structure_node(s, 4.0, true)
			elif s.is_in_group("gates") or s.name.to_lower().contains("gate"):
				var is_closed: bool = true
				if "current_state" in s:
					is_closed = (s.get("current_state") == 0) # 0 is GateState.CLOSED
				var gate_cost: int = 20 if is_closed else 1
				register_structure_node(s, 3.0, is_closed, gate_cost)
			elif s.is_in_group("walls") or s.name.to_lower().contains("wall"):
				var is_front: bool = (s.global_position.z <= 5.0)
				var wall_cost: int = 60 if is_front else 255
				register_structure_node(s, 2.0, true, wall_cost)
			else:
				register_structure_node(s, 2.5, true)


func _on_gate_state_changed(gate: Node, is_open: bool) -> void:
	if flow_field:
		var gate_cost: int = 1 if is_open else 20
		flow_field.update_obstacle(gate, not is_open, gate_cost)


func _on_structure_destroyed(structure: Node) -> void:
	if flow_field:
		flow_field.unregister_obstacle(structure)


func register_structure_node(node: Node3D, footprint_radius: float = 2.0, is_blocking: bool = true, cost: int = 255) -> void:
	var pos := node.global_position
	var half_x := footprint_radius
	var half_z := footprint_radius
	if node is WallSegment or node.name.to_lower().contains("wall"):
		var local_half := Vector3(2.0, 1.6, 0.6)
		var basis := node.global_transform.basis
		half_x = absf(basis.x.x * local_half.x) + absf(basis.z.x * local_half.z) + 0.15
		half_z = absf(basis.x.z * local_half.x) + absf(basis.z.z * local_half.z) + 0.15
	var min_pos := Vector2(pos.x - half_x, pos.z - half_z)
	var max_pos := Vector2(pos.x + half_x, pos.z + half_z)
	if flow_field:
		flow_field.register_obstacle(node, min_pos, max_pos, is_blocking, cost)


func register_obstacle_aabb(id: Variant, min_pos: Vector3, max_pos: Vector3, is_blocking: bool = true, cost: int = 255) -> void:
	if flow_field:
		flow_field.register_obstacle(id, Vector2(min_pos.x, min_pos.z), Vector2(max_pos.x, max_pos.z), is_blocking, cost)


func unregister_obstacle(id: Variant) -> void:
	if flow_field:
		flow_field.unregister_obstacle(id)


func register_goal(goal_pos: Vector3) -> void:
	if flow_field:
		flow_field.add_goal(Vector2(goal_pos.x, goal_pos.z))


func set_goals(goal_positions: Array[Vector3]) -> void:
	if flow_field:
		var g2d: Array[Vector2] = []
		for p in goal_positions:
			g2d.append(Vector2(p.x, p.z))
		flow_field.set_goals(g2d)


func clear_goals() -> void:
	if flow_field:
		flow_field.clear_goals()


func spawn_unit(
	archetype_id: int,
	position: Vector3,
	hp: float = -1.0,
	speed: float = -1.0,
	dmg: float = -1.0,
	tags: int = -1,
	rng: float = -1.0,
	cooldown: float = -1.0,
	armor: int = -1
) -> int:
	var arch: SwarmUnitArchetype = archetype_defs.get(archetype_id, null)
	
	var final_hp: float = hp if hp > 0.0 else (arch.base_hp if arch else 35.0)
	var final_speed: float = speed if speed > 0.0 else (arch.base_speed if arch else 7.2)
	var final_dmg: float = dmg if dmg >= 0.0 else (arch.base_damage if arch else 5.0)
	var final_tags: int = tags if tags >= 0 else (arch.unit_tags if arch else 1)
	var final_rng: float = rng if rng > 0.0 else (arch.attack_range if arch else 1.6)
	var final_cd: float = cooldown if cooldown > 0.0 else (arch.attack_cooldown if arch else 0.5)
	var final_armor: int = armor if armor >= 0 else (arch.armor_level if arch else 0)
	
	return swarm_data.spawn_unit(
		archetype_id,
		position,
		final_hp,
		final_speed,
		final_dmg,
		final_tags,
		final_rng,
		final_cd,
		final_armor
	)


func spawn_wave(archetype_id: int, count: int, center_pos: Vector3, spread_radius: float = 3.0) -> Array[int]:
	var spawned_indices: Array[int] = []
	for i in range(count):
		var angle := randf() * TAU
		var dist := sqrt(randf()) * spread_radius
		var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var spawn_pos := center_pos + offset
		var idx := spawn_unit(archetype_id, spawn_pos)
		if idx >= 0:
			spawned_indices.append(idx)
	return spawned_indices


func despawn_unit(idx: int) -> void:
	swarm_data.despawn_unit(idx)


func apply_damage_to_unit(idx: int, amount: float) -> bool:
	return swarm_data.apply_damage(idx, amount)


func get_active_unit_count() -> int:
	return swarm_data.active_count


func get_unit_position_3d(idx: int) -> Vector3:
	return swarm_data.get_position_3d(idx)


func get_unit_heading(idx: int) -> float:
	return swarm_data.headings[idx]


func _physics_process(delta: float) -> void:
	simulate_step(delta)


## High-performance simulation step updating flow field, spatial hash, unit steering and rendering
func simulate_step(delta: float) -> void:
	if flow_field:
		flow_field.update()
	
	if spatial_hash and swarm_data:
		spatial_hash.rebuild(swarm_data)
	
	var cap: int = swarm_data.capacity
	var alive: PackedByteArray = swarm_data.alive_mask
	var px: PackedFloat32Array = swarm_data.pos_x
	var pz: PackedFloat32Array = swarm_data.pos_z
	var vx: PackedFloat32Array = swarm_data.vel_x
	var vz: PackedFloat32Array = swarm_data.vel_z
	var headings: PackedFloat32Array = swarm_data.headings
	var speeds: PackedFloat32Array = swarm_data.move_speeds
	var arch_ids: PackedInt32Array = swarm_data.archetype_ids
	
	var min_bound_x: float = map_bounds_min.x + 0.5
	var max_bound_x: float = map_bounds_max.x - 0.5
	var min_bound_z: float = map_bounds_min.y + 0.5
	var max_bound_z: float = map_bounds_max.y - 0.5
	
	var accel_delta: float = acceleration * delta
	var accel_delta_sq: float = accel_delta * accel_delta
	var turn_weight: float = clampf(turn_speed * delta, 0.0, 1.0)
	var active_limit: int = swarm_data.active_count
	if active_limit <= 0:
		return
	var processed: int = 0
	
	var f_weight: float = flow_weight
	var s_weight: float = separation_weight
	var def_sep_rad: float = default_separation_radius
	var cached_sep := _cached_sep_radius
	var cached_sep_size := cached_sep.size()

	var has_ff: bool = (flow_field != null)
	var ff_cost: PackedByteArray = flow_field.cost_field if has_ff else PackedByteArray()
	var ff_w: int = flow_field.width if has_ff else 0
	var ff_h: int = flow_field.height if has_ff else 0
	var ff_inv_cs: float = flow_field.inv_cell_size if has_ff else 1.0
	var ff_ox: float = flow_field.origin.x if has_ff else 0.0
	var ff_oz: float = flow_field.origin.y if has_ff else 0.0
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		
		var cur_px: float = px[i]
		var cur_pz: float = pz[i]
		
		# Sample continuous bilinear flow vector without temporary Vector2 allocation
		var flow_vec: Vector2 = flow_field.sample_flow_bilinear_coords(cur_px, cur_pz) if flow_field else Vector2.ZERO
		
		# Direct flat array lookup for separation radius (zero dictionary lookups in hot loop)
		var a_id: int = arch_ids[i]
		var sep_radius: float = cached_sep[a_id] if (a_id >= 0 and a_id < cached_sep_size) else def_sep_rad
		
		var sep_force: Vector2 = spatial_hash.compute_separation_force(i, swarm_data, sep_radius, 5) if spatial_hash else Vector2.ZERO
		var sep_len_sq: float = sep_force.x * sep_force.x + sep_force.y * sep_force.y
		
		# Organic vector blending: Flow Field + Boids Separation
		var des_x: float = flow_vec.x * f_weight + sep_force.x * s_weight
		var des_z: float = flow_vec.y * f_weight + sep_force.y * s_weight
		var des_len_sq: float = des_x * des_x + des_z * des_z
		
		if des_len_sq > 0.001:
			var inv_des_len: float = 1.0 / sqrt(des_len_sq)
			des_x *= inv_des_len
			des_z *= inv_des_len
		elif flow_vec.length_squared() > 0.001:
			des_x = flow_vec.x
			des_z = flow_vec.y
		else:
			des_x = 0.0
			des_z = 0.0
		
		var spd: float = speeds[i]
		var cur_vx: float = vx[i]
		var cur_vz: float = vz[i]
		
		var target_vx: float = des_x * spd
		var target_vz: float = des_z * spd
		
		var diff_x: float = target_vx - cur_vx
		var diff_z: float = target_vz - cur_vz
		var diff_sq: float = diff_x * diff_x + diff_z * diff_z
		
		# Under extreme local separation pressure, allow responsive evasive acceleration
		var eff_accel_delta: float = accel_delta * 2.5 if sep_len_sq > 4.0 else accel_delta
		var eff_accel_sq: float = eff_accel_delta * eff_accel_delta
		
		var new_vx: float = target_vx
		var new_vz: float = target_vz
		if diff_sq > eff_accel_sq:
			var inv_diff: float = eff_accel_delta / sqrt(diff_sq)
			new_vx = cur_vx + diff_x * inv_diff
			new_vz = cur_vz + diff_z * inv_diff
		
		vx[i] = new_vx
		vz[i] = new_vz
		
		# Position integration with boundary clamping
		var next_x: float = cur_px + new_vx * delta
		var next_z: float = cur_pz + new_vz * delta

		# Obstacle collision & sliding: prevent penetrating walls or closed gates (cost >= 15)
		if has_ff:
			var gx := int(floor((next_x - ff_ox) * ff_inv_cs))
			var gz := int(floor((next_z - ff_oz) * ff_inv_cs))
			if gx >= 0 and gx < ff_w and gz >= 0 and gz < ff_h:
				var cell_cost: int = ff_cost[gz * ff_w + gx]
				if cell_cost >= 15:
					var cur_gx := int(floor((cur_px - ff_ox) * ff_inv_cs))
					var cur_gz := int(floor((cur_pz - ff_oz) * ff_inv_cs))
					var can_slide_x: bool = (cur_gz >= 0 and cur_gz < ff_h and gx >= 0 and gx < ff_w) and ff_cost[cur_gz * ff_w + gx] < 15
					var can_slide_z: bool = (gz >= 0 and gz < ff_h and cur_gx >= 0 and cur_gx < ff_w) and ff_cost[gz * ff_w + cur_gx] < 15
					if can_slide_x and not can_slide_z:
						next_z = cur_pz
						new_vz = 0.0
						vz[i] = 0.0
					elif can_slide_z and not can_slide_x:
						next_x = cur_px
						new_vx = 0.0
						vx[i] = 0.0
					else:
						next_x = cur_px
						next_z = cur_pz
						new_vx = 0.0
						new_vz = 0.0
						vx[i] = 0.0
						vz[i] = 0.0
		
		# Soft position relaxation push to prevent coordinate collapse under bottleneck congestion
		if spatial_hash and spatial_hash.last_min_dist < 0.095:
			var sep_push: float = (0.095 - spatial_hash.last_min_dist) * 0.5
			next_x += spatial_hash.last_closest_nx * sep_push
			next_z += spatial_hash.last_closest_nz * sep_push
		elif sep_len_sq > 2.0:
			var sep_mag: float = sqrt(sep_len_sq)
			var push_dist: float = clampf((sep_mag - 1.0) * 0.015, 0.0, 0.04)
			next_x += (sep_force.x / sep_mag) * push_dist
			next_z += (sep_force.y / sep_mag) * push_dist
		
		px[i] = clampf(next_x, min_bound_x, max_bound_x)
		pz[i] = clampf(next_z, min_bound_z, max_bound_z)
		
		# Smooth heading rotation facing velocity vector
		var move_sq: float = new_vx * new_vx + new_vz * new_vz
		if move_sq > 0.05:
			var target_heading: float = atan2(-new_vx, -new_vz)
			headings[i] = lerp_angle(headings[i], target_heading, turn_weight)
		
		processed += 1
		if processed >= active_limit:
			break
	
	# Kinematic contact relaxation: ensure strict minimum separation in dense clusters
	if spatial_hash and swarm_data:
		spatial_hash.resolve_unit_overlaps(swarm_data, 0.095, 2)
	
	# Update batch MultiMesh transforms for rendering
	if renderer:
		renderer.update_render_transforms(swarm_data)
