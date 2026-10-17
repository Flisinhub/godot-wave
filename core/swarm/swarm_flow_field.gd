class_name SwarmFlowField
extends RefCounted

## SwarmFlowField - 3-Phase Flow Field Navigation Engine.
## Phase 1: Cost Field with dynamic obstacle integration (walls, bunkers, gates).
## Phase 2: Integration Field using 8-directional Dijkstra/BFS from multiple goals.
## Phase 3: Flow Field with continuous bilinear vector interpolation and Boids steering blending.

const UNREACHABLE: int = 999999
const COST_PASSABLE: int = 1
const COST_IMPASSABLE: int = 255

const NEIGHBOR_DX: Array[int] = [0, 0, -1, 1, -1, 1, -1, 1]
const NEIGHBOR_DZ: Array[int] = [-1, 1, 0, 0, -1, -1, 1, 1]
const STEP_COSTS: Array[int] = [10, 10, 10, 10, 14, 14, 14, 14]

# Grid Configuration
var width: int = 128
var height: int = 128
var total_cells: int = 16384
var cell_size: float = 1.0
var inv_cell_size: float = 1.0
var origin: Vector2 = Vector2(-64.0, -64.0)

# Field Buffers
var base_cost_field: PackedByteArray = PackedByteArray()
var cost_field: PackedByteArray = PackedByteArray()
var integration_field: PackedInt32Array = PackedInt32Array()
var flow_x: PackedFloat32Array = PackedFloat32Array()
var flow_z: PackedFloat32Array = PackedFloat32Array()

# Navigation State
var goals: Array[Vector2] = []
var is_cost_field_dirty: bool = true
var is_goals_dirty: bool = true

# Obstacle Registry: key -> { "min": Vector2, "max": Vector2, "blocking": bool }
var registered_obstacles: Dictionary = {}

# Internal Min-Heap for Dijkstra
var _heap_cost: PackedInt32Array = PackedInt32Array()
var _heap_cell: PackedInt32Array = PackedInt32Array()
var _heap_size: int = 0
var _top_cost: int = 0
var _top_cell: int = 0


func _init(
	grid_width: int = 128,
	grid_height: int = 128,
	c_size: float = 1.0,
	grid_origin: Vector2 = Vector2(-64.0, -64.0)
) -> void:
	setup(grid_width, grid_height, c_size, grid_origin)


func setup(
	grid_width: int,
	grid_height: int,
	c_size: float,
	grid_origin: Vector2
) -> void:
	width = grid_width
	height = grid_height
	cell_size = max(0.1, c_size)
	inv_cell_size = 1.0 / cell_size
	origin = grid_origin
	total_cells = width * height
	
	base_cost_field.resize(total_cells)
	base_cost_field.fill(COST_PASSABLE)
	
	cost_field.resize(total_cells)
	cost_field.fill(COST_PASSABLE)
	
	integration_field.resize(total_cells)
	integration_field.fill(UNREACHABLE)
	
	flow_x.resize(total_cells)
	flow_x.fill(0.0)
	flow_z.resize(total_cells)
	flow_z.fill(0.0)
	
	_heap_cost.resize(total_cells * 2)
	_heap_cell.resize(total_cells * 2)
	_heap_size = 0
	
	is_cost_field_dirty = true
	is_goals_dirty = true


# -----------------------------------------------------------------------------
# Phase 1: Cost Field & Dynamic Obstacle Management
# -----------------------------------------------------------------------------

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx := int(floor((world_pos.x - origin.x) * inv_cell_size))
	var gz := int(floor((world_pos.y - origin.y) * inv_cell_size))
	return Vector2i(gx, gz)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return origin + Vector2((float(grid_pos.x) + 0.5) * cell_size, (float(grid_pos.y) + 0.5) * cell_size)


func is_valid_cell(gx: int, gz: int) -> bool:
	return gx >= 0 and gx < width and gz >= 0 and gz < height


func set_cell_cost(gx: int, gz: int, cost: int) -> void:
	if is_valid_cell(gx, gz):
		var idx := gz * width + gx
		var clamped_cost := clampi(cost, 1, 255)
		base_cost_field[idx] = clamped_cost
		if cost_field[idx] != clamped_cost:
			cost_field[idx] = clamped_cost
			is_cost_field_dirty = true


func get_cell_cost(gx: int, gz: int) -> int:
	if is_valid_cell(gx, gz):
		return cost_field[gz * width + gx]
	return COST_IMPASSABLE


func stamp_obstacle_aabb(world_min: Vector2, world_max: Vector2, cost: int = COST_IMPASSABLE) -> void:
	var g_min := world_to_grid(world_min)
	var g_max := world_to_grid(world_max)
	
	var min_x := clampi(mini(g_min.x, g_max.x), 0, width - 1)
	var max_x := clampi(maxi(g_min.x, g_max.x), 0, width - 1)
	var min_z := clampi(mini(g_min.y, g_max.y), 0, height - 1)
	var max_z := clampi(maxi(g_min.y, g_max.y), 0, height - 1)
	
	for gz in range(min_z, max_z + 1):
		var row := gz * width
		for gx in range(min_x, max_x + 1):
			var idx := row + gx
			base_cost_field[idx] = cost
			cost_field[idx] = cost
	
	is_cost_field_dirty = true


func _stamp_cost_runtime(world_min: Vector2, world_max: Vector2, cost: int = COST_IMPASSABLE) -> void:
	var g_min := world_to_grid(world_min)
	var g_max := world_to_grid(world_max)
	
	var min_x := clampi(mini(g_min.x, g_max.x), 0, width - 1)
	var max_x := clampi(maxi(g_min.x, g_max.x), 0, width - 1)
	var min_z := clampi(mini(g_min.y, g_max.y), 0, height - 1)
	var max_z := clampi(maxi(g_min.y, g_max.y), 0, height - 1)
	
	for gz in range(min_z, max_z + 1):
		var row := gz * width
		for gx in range(min_x, max_x + 1):
			cost_field[row + gx] = cost


func register_obstacle(id: Variant, world_min: Vector2, world_max: Vector2, is_blocking: bool = true, cost: int = COST_IMPASSABLE) -> void:
	registered_obstacles[id] = {
		"min": world_min,
		"max": world_max,
		"blocking": is_blocking,
		"cost": cost
	}
	is_cost_field_dirty = true


func update_obstacle(id: Variant, is_blocking: bool, cost: int = COST_IMPASSABLE) -> void:
	if registered_obstacles.has(id):
		var changed: bool = false
		if registered_obstacles[id]["blocking"] != is_blocking:
			registered_obstacles[id]["blocking"] = is_blocking
			changed = true
		if registered_obstacles[id].get("cost", COST_IMPASSABLE) != cost:
			registered_obstacles[id]["cost"] = cost
			changed = true
		if changed:
			is_cost_field_dirty = true


func unregister_obstacle(id: Variant) -> void:
	if registered_obstacles.erase(id):
		is_cost_field_dirty = true


func rebuild_cost_field() -> void:
	cost_field = base_cost_field.duplicate()
	for obs in registered_obstacles.values():
		if obs["blocking"]:
			var obstacle_cost: int = obs.get("cost", COST_IMPASSABLE)
			_stamp_cost_runtime(obs["min"], obs["max"], obstacle_cost)


# -----------------------------------------------------------------------------
# Phase 2: Multi-Goal Dijkstra / BFS Integration Field
# -----------------------------------------------------------------------------

func set_goals(new_goals: Array[Vector2]) -> void:
	goals = new_goals.duplicate()
	is_goals_dirty = true


func add_goal(world_pos: Vector2) -> void:
	if not goals.has(world_pos):
		goals.append(world_pos)
		is_goals_dirty = true


func clear_goals() -> void:
	goals.clear()
	is_goals_dirty = true


func _heap_clear() -> void:
	_heap_size = 0


func _heap_push(cost: int, cell: int) -> void:
	if _heap_size >= _heap_cost.size():
		var new_cap: int = _heap_cost.size() * 2
		_heap_cost.resize(new_cap)
		_heap_cell.resize(new_cap)
	
	var i := _heap_size
	_heap_size += 1
	while i > 0:
		var parent := (i - 1) >> 1
		if _heap_cost[parent] <= cost:
			break
		_heap_cost[i] = _heap_cost[parent]
		_heap_cell[i] = _heap_cell[parent]
		i = parent
	_heap_cost[i] = cost
	_heap_cell[i] = cell


func _heap_pop() -> bool:
	if _heap_size == 0:
		return false
	
	_top_cost = _heap_cost[0]
	_top_cell = _heap_cell[0]
	_heap_size -= 1
	
	if _heap_size > 0:
		var last_cost := _heap_cost[_heap_size]
		var last_cell := _heap_cell[_heap_size]
		var i := 0
		var half := _heap_size >> 1
		while i < half:
			var left := (i << 1) + 1
			var right := left + 1
			var best := left
			if right < _heap_size and _heap_cost[right] < _heap_cost[left]:
				best = right
			if last_cost <= _heap_cost[best]:
				break
			_heap_cost[i] = _heap_cost[best]
			_heap_cell[i] = _heap_cell[best]
			i = best
		_heap_cost[i] = last_cost
		_heap_cell[i] = last_cell
	
	return true


func compute_integration_field() -> void:
	integration_field.fill(UNREACHABLE)
	_heap_clear()
	
	# Seed all reachable goals with cost 0
	for goal in goals:
		var g_coord := world_to_grid(goal)
		if is_valid_cell(g_coord.x, g_coord.y):
			var idx := g_coord.y * width + g_coord.x
			if cost_field[idx] != COST_IMPASSABLE:
				integration_field[idx] = 0
				_heap_push(0, idx)
			else:
				# Goal is placed on an impassable structure footprint (e.g. CommandCenter).
				# Seed adjacent passable perimeter cells at distance 0 so Dijkstra expands into walkable terrain.
				var queue: PackedInt32Array = PackedInt32Array([idx])
				var visited: Dictionary = {idx: true}
				var head: int = 0
				var max_search: int = 2048
				
				while head < queue.size() and head < max_search:
					var curr: int = queue[head]
					head += 1
					var cx: int = curr % width
					var cz: int = curr / width
					
					for i in range(8):
						var nx: int = cx + NEIGHBOR_DX[i]
						var nz: int = cz + NEIGHBOR_DZ[i]
						if nx < 0 or nx >= width or nz < 0 or nz >= height:
							continue
						var n_idx: int = nz * width + nx
						if visited.has(n_idx):
							continue
						visited[n_idx] = true
						
						if cost_field[n_idx] != COST_IMPASSABLE:
							if integration_field[n_idx] > 0:
								integration_field[n_idx] = 0
								_heap_push(0, n_idx)
						else:
							queue.append(n_idx)
	
	# Dijkstra wave expansion
	var w := width
	var h := height
	while _heap_pop():
		var curr_cost := _top_cost
		var curr_cell := _top_cell
		
		if curr_cost > integration_field[curr_cell]:
			continue
		
		var cx := curr_cell % w
		var cz := curr_cell / w
		
		for i in range(8):
			var dx: int = NEIGHBOR_DX[i]
			var dz: int = NEIGHBOR_DZ[i]
			var nx := cx + dx
			var nz := cz + dz
			
			if nx < 0 or nx >= w or nz < 0 or nz >= h:
				continue
			
			var n_idx := nz * w + nx
			var n_cost: int = cost_field[n_idx]
			if n_cost == COST_IMPASSABLE:
				continue
			
			# Prevent cutting corners between two impassable diagonal obstacles
			if dx != 0 and dz != 0:
				if cost_field[cz * w + nx] == COST_IMPASSABLE and cost_field[nz * w + cx] == COST_IMPASSABLE:
					continue
			
			var step_weight: int = STEP_COSTS[i]
			var new_cost: int = curr_cost + step_weight * n_cost
			
			if new_cost < integration_field[n_idx]:
				integration_field[n_idx] = new_cost
				_heap_push(new_cost, n_idx)


# -----------------------------------------------------------------------------
# Phase 3: Flow Field Computation & Bilinear Interpolation
# -----------------------------------------------------------------------------

func compute_flow_field() -> void:
	var w := width
	var h := height
	
	for cz in range(h):
		var row := cz * w
		for cx in range(w):
			var idx := row + cx
			var curr_cost: int = integration_field[idx]
			
			if cost_field[idx] == COST_IMPASSABLE or curr_cost == 0 or curr_cost >= UNREACHABLE:
				flow_x[idx] = 0.0
				flow_z[idx] = 0.0
				continue
			
			# Continuous gradient descent from integration field (negative gradient points towards goal)
			var int_left: int = integration_field[row + cx - 1] if cx > 0 else curr_cost
			var int_right: int = integration_field[row + cx + 1] if cx < w - 1 else curr_cost
			var int_up: int = integration_field[(cz - 1) * w + cx] if cz > 0 else curr_cost
			var int_down: int = integration_field[(cz + 1) * w + cx] if cz < h - 1 else curr_cost
			
			var grad_x: float = 0.0
			var grad_z: float = 0.0
			
			if int_left < UNREACHABLE and int_right < UNREACHABLE:
				grad_x = float(int_left - int_right)
			elif int_left < UNREACHABLE:
				grad_x = float(int_left - curr_cost) * 2.0
			elif int_right < UNREACHABLE:
				grad_x = float(curr_cost - int_right) * 2.0
			
			if int_up < UNREACHABLE and int_down < UNREACHABLE:
				grad_z = float(int_up - int_down)
			elif int_up < UNREACHABLE:
				grad_z = float(int_up - curr_cost) * 2.0
			elif int_down < UNREACHABLE:
				grad_z = float(curr_cost - int_down) * 2.0
			
			var grad_len_sq: float = grad_x * grad_x + grad_z * grad_z
			if grad_len_sq > 0.0001:
				var inv_len: float = 1.0 / sqrt(grad_len_sq)
				flow_x[idx] = grad_x * inv_len
				flow_z[idx] = grad_z * inv_len
			else:
				# Fallback to discrete 8-neighbor minimum if gradient is flat
				var min_cost: int = curr_cost
				var best_dx: int = 0
				var best_dz: int = 0
				
				for i in range(8):
					var dx: int = NEIGHBOR_DX[i]
					var dz: int = NEIGHBOR_DZ[i]
					var nx := cx + dx
					var nz := cz + dz
					
					if nx < 0 or nx >= w or nz < 0 or nz >= h:
						continue
					
					var n_idx := nz * w + nx
					if cost_field[n_idx] == COST_IMPASSABLE:
						continue
					
					var n_cost: int = integration_field[n_idx]
					if n_cost < min_cost:
						min_cost = n_cost
						best_dx = dx
						best_dz = dz
				
				if best_dx != 0 or best_dz != 0:
					var length: float = sqrt(float(best_dx * best_dx + best_dz * best_dz))
					flow_x[idx] = float(best_dx) / length
					flow_z[idx] = float(best_dz) / length
				else:
					flow_x[idx] = 0.0
					flow_z[idx] = 0.0


## High-performance continuous bilinear sampling without intermediate allocations.
func sample_flow_bilinear(world_pos: Vector2) -> Vector2:
	return sample_flow_bilinear_coords(world_pos.x, world_pos.y)


func sample_flow_bilinear_coords(world_x: float, world_z: float) -> Vector2:
	var gx: float = (world_x - origin.x) * inv_cell_size - 0.5
	var gz: float = (world_z - origin.y) * inv_cell_size - 0.5
	
	var x0: int = int(floor(gx))
	var z0: int = int(floor(gz))
	var x1: int = x0 + 1
	var z1: int = z0 + 1
	
	var u: float = clampf(gx - float(x0), 0.0, 1.0)
	var v: float = clampf(gz - float(z0), 0.0, 1.0)
	var one_minus_u: float = 1.0 - u
	var one_minus_v: float = 1.0 - v
	
	var cx0: int = clampi(x0, 0, width - 1)
	var cx1: int = clampi(x1, 0, width - 1)
	var cz0: int = clampi(z0, 0, height - 1)
	var cz1: int = clampi(z1, 0, height - 1)
	
	var row0: int = cz0 * width
	var row1: int = cz1 * width
	var idx00: int = row0 + cx0
	var idx10: int = row0 + cx1
	var idx01: int = row1 + cx0
	var idx11: int = row1 + cx1
	
	var top_x: float = one_minus_u * flow_x[idx00] + u * flow_x[idx10]
	var top_z: float = one_minus_u * flow_z[idx00] + u * flow_z[idx10]
	var bot_x: float = one_minus_u * flow_x[idx01] + u * flow_x[idx11]
	var bot_z: float = one_minus_u * flow_z[idx01] + u * flow_z[idx11]
	
	var fx: float = one_minus_v * top_x + v * bot_x
	var fz: float = one_minus_v * top_z + v * bot_z
	
	var len_sq: float = fx * fx + fz * fz
	if len_sq > 0.0001:
		var inv_len: float = 1.0 / sqrt(len_sq)
		return Vector2(fx * inv_len, fz * inv_len)
	
	return Vector2.ZERO


## Nearest-neighbor flow vector lookup (fallback/benchmark comparison)
func sample_flow_nearest(world_pos: Vector2) -> Vector2:
	var g := world_to_grid(world_pos)
	if is_valid_cell(g.x, g.y):
		var idx := g.y * width + g.x
		return Vector2(flow_x[idx], flow_z[idx])
	return Vector2.ZERO


## Full pipeline update: re-evaluates Cost, Integration, and Flow fields if state changed.
func update() -> bool:
	if not is_cost_field_dirty and not is_goals_dirty:
		return false
	
	if is_cost_field_dirty:
		rebuild_cost_field()
	
	compute_integration_field()
	compute_flow_field()
	
	is_cost_field_dirty = false
	is_goals_dirty = false
	return true
