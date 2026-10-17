class_name SwarmSpatialHash
extends RefCounted

## SwarmSpatialHash - 2D Uniform Grid Spatial Hash for O(N) neighbor queries and Boids separation.
## Employs linked-list bucket arrays (grid_head, grid_next) with center-first neighbor traversal
## to achieve zero runtime heap allocation and 60+ FPS for >1,000 entities.

const ADJ_DX: Array[int] = [-1, 0, 1, -1, 1, -1, 0, 1]
const ADJ_DZ: Array[int] = [-1, -1, -1, 0, 0, 1, 1, 1]
const OVERLAP_ADJ_DX: Array[int] = [1, -1, 0, 1]
const OVERLAP_ADJ_DZ: Array[int] = [0, 1, 1, 1]

var cell_size: float = 1.2
var inv_cell_size: float = 0.833333
var bounds_min: Vector2 = Vector2(-64.0, -64.0)
var bounds_max: Vector2 = Vector2(64.0, 64.0)
var grid_cols: int = 107
var grid_rows: int = 107
var total_cells: int = 11449

var grid_head: PackedInt32Array = PackedInt32Array()
var grid_next: PackedInt32Array = PackedInt32Array()

var _cached_pos_x: PackedFloat32Array = PackedFloat32Array()
var _cached_pos_z: PackedFloat32Array = PackedFloat32Array()
var _cached_alive: PackedByteArray = PackedByteArray()

var last_min_dist: float = 999.0
var last_closest_nx: float = 0.0
var last_closest_nz: float = 0.0


func _init(
	min_bounds: Vector2 = Vector2(-64.0, -64.0),
	max_bounds: Vector2 = Vector2(64.0, 64.0),
	c_size: float = 1.2,
	max_entities: int = 4096
) -> void:
	setup(min_bounds, max_bounds, c_size, max_entities)


func setup(
	min_bounds: Vector2,
	max_bounds: Vector2,
	c_size: float,
	max_entities: int
) -> void:
	bounds_min = min_bounds
	bounds_max = max_bounds
	cell_size = max(0.1, c_size)
	inv_cell_size = 1.0 / cell_size
	
	var width: float = bounds_max.x - bounds_min.x
	var height: float = bounds_max.y - bounds_min.y
	
	grid_cols = int(ceil(width / cell_size))
	grid_rows = int(ceil(height / cell_size))
	total_cells = grid_cols * grid_rows
	
	grid_head.resize(total_cells)
	grid_head.fill(-1)
	
	grid_next.resize(max_entities)
	grid_next.fill(-1)


func rebuild(swarm_data: SwarmData) -> void:
	grid_head.fill(-1)
	
	if grid_next.size() < swarm_data.capacity:
		grid_next.resize(swarm_data.capacity)
	grid_next.fill(-1)
	
	_cached_pos_x = swarm_data.pos_x
	_cached_pos_z = swarm_data.pos_z
	_cached_alive = swarm_data.alive_mask
	
	var cap: int = swarm_data.capacity
	var alive: PackedByteArray = _cached_alive
	var px: PackedFloat32Array = _cached_pos_x
	var pz: PackedFloat32Array = _cached_pos_z
	var b_min_x: float = bounds_min.x
	var b_min_y: float = bounds_min.y
	var inv_cell: float = inv_cell_size
	var cols: int = grid_cols
	var rows: int = grid_rows
	var active_limit: int = swarm_data.active_count
	var processed: int = 0
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		
		var cx: int = int(floor((px[i] - b_min_x) * inv_cell))
		var cz: int = int(floor((pz[i] - b_min_y) * inv_cell))
		
		if cx >= 0 and cx < cols and cz >= 0 and cz < rows:
			var cell_idx: int = cz * cols + cx
			grid_next[i] = grid_head[cell_idx]
			grid_head[cell_idx] = i
		
		processed += 1
		if processed >= active_limit:
			break


func query_radius(center: Vector2, radius: float, swarm_data: SwarmData) -> PackedInt32Array:
	var result := PackedInt32Array()
	var inv_cell: float = inv_cell_size
	var min_cx: int = clampi(int(floor((center.x - radius - bounds_min.x) * inv_cell)), 0, grid_cols - 1)
	var max_cx: int = clampi(int(floor((center.x + radius - bounds_min.x) * inv_cell)), 0, grid_cols - 1)
	var min_cz: int = clampi(int(floor((center.y - radius - bounds_min.y) * inv_cell)), 0, grid_rows - 1)
	var max_cz: int = clampi(int(floor((center.y + radius - bounds_min.y) * inv_cell)), 0, grid_rows - 1)
	
	var r_sq: float = radius * radius
	var px: PackedFloat32Array = swarm_data.pos_x
	var pz: PackedFloat32Array = swarm_data.pos_z
	var alive: PackedByteArray = swarm_data.alive_mask
	var cols: int = grid_cols
	
	for cz in range(min_cz, max_cz + 1):
		var row_offset: int = cz * cols
		for cx in range(min_cx, max_cx + 1):
			var cell_idx: int = row_offset + cx
			var curr: int = grid_head[cell_idx]
			while curr != -1:
				if alive[curr] == 1:
					var dx: float = px[curr] - center.x
					var dz: float = pz[curr] - center.y
					if dx * dx + dz * dz <= r_sq:
						result.append(curr)
				curr = grid_next[curr]
	
	return result


func compute_separation_force(
	unit_idx: int,
	swarm_data: SwarmData,
	separation_radius: float,
	max_neighbors: int = 5
) -> Vector2:
	last_min_dist = 999.0
	last_closest_nx = 0.0
	last_closest_nz = 0.0
	
	if separation_radius <= 0.001:
		return Vector2.ZERO
	
	var pos_x_arr: PackedFloat32Array = _cached_pos_x if _cached_pos_x.size() > unit_idx else swarm_data.pos_x
	var pos_z_arr: PackedFloat32Array = _cached_pos_z if _cached_pos_z.size() > unit_idx else swarm_data.pos_z
	var alive: PackedByteArray = _cached_alive if _cached_alive.size() > unit_idx else swarm_data.alive_mask
	
	var px: float = pos_x_arr[unit_idx]
	var pz: float = pos_z_arr[unit_idx]
	var inv_cell: float = inv_cell_size
	
	var cx: int = int(floor((px - bounds_min.x) * inv_cell))
	var cz: int = int(floor((pz - bounds_min.y) * inv_cell))
	
	var force_x: float = 0.0
	var force_z: float = 0.0
	var sep_sq: float = separation_radius * separation_radius
	var inv_sep: float = 1.0 / separation_radius
	var cols: int = grid_cols
	var rows: int = grid_rows
	var checked_count: int = 0
	
	# 1. Center cell first (highest probability of closest neighbor repulsion)
	if cx >= 0 and cx < cols and cz >= 0 and cz < rows:
		var curr: int = grid_head[cz * cols + cx]
		while curr != -1:
			if curr != unit_idx and alive[curr] == 1:
				var diff_x: float = px - pos_x_arr[curr]
				var diff_z: float = pz - pos_z_arr[curr]
				var dist_sq: float = diff_x * diff_x + diff_z * diff_z
				
				if dist_sq < sep_sq:
					if dist_sq <= 0.0001:
						var base_angle: float = float((abs(unit_idx - curr) * 137 + mini(unit_idx, curr) * 31 + 17) % 360) * (PI / 180.0)
						var angle: float = base_angle + (PI if unit_idx < curr else 0.0)
						var rep_nx: float = cos(angle)
						var rep_nz: float = sin(angle)
						force_x += rep_nx * 5.0
						force_z += rep_nz * 5.0
						if 0.0 < last_min_dist:
							last_min_dist = 0.0
							last_closest_nx = rep_nx
							last_closest_nz = rep_nz
						checked_count += 1
						if checked_count >= max_neighbors:
							return Vector2(force_x, force_z)
					else:
						var d: float = sqrt(dist_sq)
						var inv_d: float = 1.0 / d
						var nx: float = diff_x * inv_d
						var nz: float = diff_z * inv_d
						if d < last_min_dist:
							last_min_dist = d
							last_closest_nx = nx
							last_closest_nz = nz
						var weight: float = (1.0 - (d * inv_sep)) / (dist_sq + 0.004)
						if d < 0.15:
							weight *= 2.5
						force_x += diff_x * weight
						force_z += diff_z * weight
						checked_count += 1
						if checked_count >= max_neighbors:
							return Vector2(force_x, force_z)
			curr = grid_next[curr]
	
	# 2. Outer 8 neighboring cells if cap not met
	if checked_count < max_neighbors:
		for k in range(8):
			var ncx: int = cx + ADJ_DX[k]
			var ncz: int = cz + ADJ_DZ[k]
			if ncx < 0 or ncx >= cols or ncz < 0 or ncz >= rows:
				continue
			
			var curr: int = grid_head[ncz * cols + ncx]
			while curr != -1:
				if curr != unit_idx and alive[curr] == 1:
					var diff_x: float = px - pos_x_arr[curr]
					var diff_z: float = pz - pos_z_arr[curr]
					var dist_sq: float = diff_x * diff_x + diff_z * diff_z
					
					if dist_sq < sep_sq:
						if dist_sq <= 0.0001:
							var base_angle: float = float((abs(unit_idx - curr) * 137 + mini(unit_idx, curr) * 31 + 17) % 360) * (PI / 180.0)
							var angle: float = base_angle + (PI if unit_idx < curr else 0.0)
							var rep_nx: float = cos(angle)
							var rep_nz: float = sin(angle)
							force_x += rep_nx * 5.0
							force_z += rep_nz * 5.0
							if 0.0 < last_min_dist:
								last_min_dist = 0.0
								last_closest_nx = rep_nx
								last_closest_nz = rep_nz
							checked_count += 1
							if checked_count >= max_neighbors:
								return Vector2(force_x, force_z)
						else:
							var d: float = sqrt(dist_sq)
							var inv_d: float = 1.0 / d
							var nx: float = diff_x * inv_d
							var nz: float = diff_z * inv_d
							if d < last_min_dist:
								last_min_dist = d
								last_closest_nx = nx
								last_closest_nz = nz
							var weight: float = (1.0 - (d * inv_sep)) / (dist_sq + 0.004)
							if d < 0.15:
								weight *= 2.5
							force_x += diff_x * weight
							force_z += diff_z * weight
							checked_count += 1
							if checked_count >= max_neighbors:
								return Vector2(force_x, force_z)
				curr = grid_next[curr]
			if checked_count >= max_neighbors:
				break
	
	return Vector2(force_x, force_z)


## High-performance kinematic contact relaxation pass to ensure hard minimum separation under high density.
func resolve_unit_overlaps(swarm_data: SwarmData, min_dist: float = 0.095, iterations: int = 2) -> void:
	for iter in range(iterations):
		_relax_unit_overlaps(swarm_data, min_dist)
		if iter + 1 < iterations:
			rebuild(swarm_data)


func _relax_unit_overlaps(swarm_data: SwarmData, min_dist: float) -> void:
	var cap: int = swarm_data.capacity
	var alive: PackedByteArray = swarm_data.alive_mask
	var px: PackedFloat32Array = swarm_data.pos_x
	var pz: PackedFloat32Array = swarm_data.pos_z
	var cols: int = grid_cols
	var rows: int = grid_rows
	var c_size: float = cell_size
	var inv_cell: float = inv_cell_size
	var b_min_x: float = bounds_min.x
	var b_min_y: float = bounds_min.y
	var min_dist_sq: float = min_dist * min_dist
	var active_limit: int = swarm_data.active_count
	var processed: int = 0
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		
		var cur_x: float = px[i]
		var cur_z: float = pz[i]
		var rel_x: float = cur_x - b_min_x
		var rel_z: float = cur_z - b_min_y
		var cx: int = int(floor(rel_x * inv_cell))
		var cz: int = int(floor(rel_z * inv_cell))
		
		if cx >= 0 and cx < cols and cz >= 0 and cz < rows:
			# 1. Center cell check (curr > i ensures each pair checked once)
			var curr: int = grid_head[cz * cols + cx]
			while curr != -1:
				if curr > i and alive[curr] == 1:
					var dx: float = cur_x - px[curr]
					var dz: float = cur_z - pz[curr]
					var dist_sq: float = dx * dx + dz * dz
					
					if dist_sq < min_dist_sq:
						var d: float
						var nx: float
						var nz: float
						if dist_sq <= 0.000001:
							var angle: float = float((abs(i - curr) * 137 + mini(i, curr) * 31 + 17) % 360) * (PI / 180.0)
							nx = cos(angle)
							nz = sin(angle)
							d = 0.0
						else:
							d = sqrt(dist_sq)
							var inv_d: float = 1.0 / d
							nx = dx * inv_d
							nz = dz * inv_d
						
						var push: float = (min_dist - d) * 0.5
						cur_x += nx * push
						cur_z += nz * push
						px[curr] -= nx * push
						pz[curr] -= nz * push
						px[i] = cur_x
						pz[i] = cur_z
				curr = grid_next[curr]
			
			# 2. Selective boundary crossing: only check adjacent cells if unit is within min_dist of cell border
			var cell_left: float = float(cx) * c_size
			var cell_bot: float = float(cz) * c_size
			var near_left: bool = (rel_x - cell_left) < min_dist and (cx > 0)
			var near_right: bool = (cell_left + c_size - rel_x) < min_dist and (cx + 1 < cols)
			var near_bot: bool = (rel_z - cell_bot) < min_dist and (cz > 0)
			var near_top: bool = (cell_bot + c_size - rel_z) < min_dist and (cz + 1 < rows)
			
			if near_left:
				var n_curr: int = grid_head[cz * cols + (cx - 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else -1.0
							var nz: float = dz * inv_d if d > 0.000001 else 0.0
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_right:
				var n_curr: int = grid_head[cz * cols + (cx + 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else 1.0
							var nz: float = dz * inv_d if d > 0.000001 else 0.0
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_bot:
				var n_curr: int = grid_head[(cz - 1) * cols + cx]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else 0.0
							var nz: float = dz * inv_d if d > 0.000001 else -1.0
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_top:
				var n_curr: int = grid_head[(cz + 1) * cols + cx]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else 0.0
							var nz: float = dz * inv_d if d > 0.000001 else 1.0
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_right and near_top:
				var n_curr: int = grid_head[(cz + 1) * cols + (cx + 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else 0.7071
							var nz: float = dz * inv_d if d > 0.000001 else 0.7071
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_left and near_top:
				var n_curr: int = grid_head[(cz + 1) * cols + (cx - 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else -0.7071
							var nz: float = dz * inv_d if d > 0.000001 else 0.7071
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_right and near_bot:
				var n_curr: int = grid_head[(cz - 1) * cols + (cx + 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else 0.7071
							var nz: float = dz * inv_d if d > 0.000001 else -0.7071
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
			
			if near_left and near_bot:
				var n_curr: int = grid_head[(cz - 1) * cols + (cx - 1)]
				while n_curr != -1:
					if n_curr > i and alive[n_curr] == 1:
						var dx: float = cur_x - px[n_curr]
						var dz: float = cur_z - pz[n_curr]
						var dist_sq: float = dx * dx + dz * dz
						if dist_sq < min_dist_sq:
							var d: float = sqrt(dist_sq) if dist_sq > 0.000001 else 0.0
							var inv_d: float = 1.0 / d if d > 0.000001 else 1.0
							var nx: float = dx * inv_d if d > 0.000001 else -0.7071
							var nz: float = dz * inv_d if d > 0.000001 else -0.7071
							var push: float = (min_dist - d) * 0.5
							cur_x += nx * push
							cur_z += nz * push
							px[n_curr] -= nx * push
							pz[n_curr] -= nz * push
							px[i] = cur_x
							pz[i] = cur_z
					n_curr = grid_next[n_curr]
		
		processed += 1
		if processed >= active_limit:
			break
