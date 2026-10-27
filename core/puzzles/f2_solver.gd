class_name F2Solver
extends RefCounted

## F2Solver - Field-of-2 (GF(2)) Gaussian Elimination Solver for Cyclic Automata (Tasks 9.7, 9.11).
## Solves the matrix equation A * x = b over F2 (mod 2) with XOR arithmetic.
## Specifically tailored for SFE5's 8-pedestal Lights Out ring automaton.

const SIZE: int = 8


## Constructs the 8x8 circulant adjacency matrix over F2:
## Row i has 1s at (i-1)%8, i, (i+1)%8.
static func get_c8_matrix() -> Array[Array]:
	var matrix: Array[Array] = []
	for i in range(SIZE):
		var row: Array = []
		for j in range(SIZE):
			var is_neighbor: bool = (j == i) or (j == (i - 1 + SIZE) % SIZE) or (j == (i + 1) % SIZE)
			row.append(1 if is_neighbor else 0)
		matrix.append(row)
	return matrix


## Solves A * x = b over F2.
## initial_state: current 8-bit vector [s0, s1, ..., s7]
## target_state: target 8-bit vector (defaults to all 1s if empty)
## Returns {"solvable": bool, "solution": Array[int], "press_count": int}
static func solve_c8(initial_state: Array, target_state: Array = []) -> Dictionary:
	if target_state.is_empty():
		target_state = [1, 1, 1, 1, 1, 1, 1, 1]

	if initial_state.size() != SIZE or target_state.size() != SIZE:
		return {"solvable": false, "solution": [], "press_count": 0}

	# Vector b = target_state XOR initial_state (required net toggles)
	var b: Array[int] = []
	for i in range(SIZE):
		b.append((int(target_state[i]) ^ int(initial_state[i])) & 1)

	# Build augmented matrix [A | b]
	var mat: Array[Array] = get_c8_matrix()
	for i in range(SIZE):
		mat[i].append(b[i])

	# Gaussian Elimination with Partial Pivoting over F2 (XOR)
	var rank: int = 0
	for col in range(SIZE):
		var pivot_row: int = -1
		for r in range(rank, SIZE):
			if mat[r][col] == 1:
				pivot_row = r
				break

		if pivot_row == -1:
			continue # Free variable / column has no pivot

		# Swap current rank row with pivot_row
		var temp: Array = mat[rank]
		mat[rank] = mat[pivot_row]
		mat[pivot_row] = temp

		# Eliminate all other rows in this column using XOR
		for r in range(SIZE):
			if r != rank and mat[r][col] == 1:
				for c in range(col, SIZE + 1):
					mat[r][c] = (mat[r][c] ^ mat[rank][c]) & 1

		rank += 1

	# Check for inconsistency: row with all 0s in A but 1 in b
	for r in range(rank, SIZE):
		if mat[r][SIZE] == 1:
			return {"solvable": false, "solution": [], "press_count": 0}

	# Back-substitution to extract solution
	var solution: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	for r in range(rank):
		# Find the leading 1 in row r
		var leading_col: int = -1
		for c in range(SIZE):
			if mat[r][c] == 1:
				leading_col = c
				break
		if leading_col != -1:
			solution[leading_col] = mat[r][SIZE]

	var count: int = 0
	for val in solution:
		if val == 1:
			count += 1

	return {
		"solvable": true,
		"solution": solution,
		"press_count": count
	}


## Simulates toggles and verifies whether a solution correctly reaches the target state.
static func verify_solution(initial_state: Array, solution: Array, target_state: Array = []) -> bool:
	if target_state.is_empty():
		target_state = [1, 1, 1, 1, 1, 1, 1, 1]

	var state: Array[int] = []
	for v in initial_state:
		state.append(int(v) & 1)

	for p in range(solution.size()):
		if solution[p] == 1:
			state[p] ^= 1
			state[(p - 1 + SIZE) % SIZE] ^= 1
			state[(p + 1) % SIZE] ^= 1

	for i in range(SIZE):
		if state[i] != target_state[i]:
			return false
	return true


## Generates a deterministic solvable state based on a RandomNumberGenerator (Task 9.10).
static func generate_solvable_state(rng: RandomNumberGenerator, min_toggles: int = 2) -> Array[int]:
	# Select random presses x in F2^8 ensuring at least min_toggles
	var x: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	var toggles: int = 0
	while toggles < min_toggles:
		x.clear()
		toggles = 0
		for i in range(SIZE):
			var bit: int = rng.randi_range(0, 1)
			x.append(bit)
			if bit == 1:
				toggles += 1

	# State = Target (all 1s) XOR (A * x)
	var initial: Array[int] = [1, 1, 1, 1, 1, 1, 1, 1]
	for p in range(SIZE):
		if x[p] == 1:
			initial[p] ^= 1
			initial[(p - 1 + SIZE) % SIZE] ^= 1
			initial[(p + 1) % SIZE] ^= 1

	return initial


## Analyzes all 256 possible 8-bit configurations.
## Returns total_configurations, solvable_count, unsolvable_count, and verifies every solution.
static func test_all_256_configurations() -> Dictionary:
	var total: int = 256
	var solvable: int = 0
	var unsolvable: int = 0
	var verified: int = 0

	for byte_val in range(256):
		var state: Array[int] = []
		for b in range(SIZE):
			state.append((byte_val >> b) & 1)

		var res: Dictionary = solve_c8(state)
		if res["solvable"]:
			solvable += 1
			if verify_solution(state, res["solution"]):
				verified += 1
		else:
			unsolvable += 1

	return {
		"total": total,
		"solvable": solvable,
		"unsolvable": unsolvable,
		"verified": verified
	}
