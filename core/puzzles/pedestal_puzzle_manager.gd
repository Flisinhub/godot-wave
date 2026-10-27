class_name PedestalPuzzleManager
extends Node3D

## PedestalPuzzleManager - Spatial 8 Pedestals Algorithmic Puzzle.
## Implements regular octagon topology with dual resolution models:
## Mode A (Octagram {8/3}): Validates cyclic sequence [0, 3, 6, 1, 4, 7, 2, 5].
## Mode B (Lights Out C8): Group-theoretic toggle automaton over F2 on cyclic ring C8.

signal puzzle_step_advanced(step_index: int, total_steps: int)
signal puzzle_failed(pedestal_id: int)
signal puzzle_solved(reward_data: Dictionary)
signal c8_state_changed(new_state: PackedByteArray)
signal pedestal_state_updated(pedestal_id: int, is_active: bool)

const F2Solver = preload("res://core/puzzles/f2_solver.gd")

enum PuzzleMode { SEQUENCE_OCTAGRAM, LIGHTS_OUT_C8 }

@export var mode: PuzzleMode = PuzzleMode.LIGHTS_OUT_C8
@export var ring_radius: float = 8.0
@export var target_sequence: Array[int] = [0, 3, 6, 1, 4, 7, 2, 5]
@export var match_seed: int = 123456

var current_step_index: int = 0
var c8_state: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
var is_solved: bool = false
var pedestals: Array[Node3D] = []
var debug_hint_mode: bool = false


func _ready() -> void:
	_initialize_pedestal_nodes()


func _initialize_pedestal_nodes() -> void:
	pedestals.clear()
	for i in range(8):
		var p_name: String = "Pedestal_" + str(i)
		var p_node: Node3D = get_node_or_null(p_name)
		if p_node:
			pedestals.append(p_node)
			if p_node.has_signal("pedestal_stepped"):
				p_node.connect("pedestal_stepped", Callable(self, "step_pedestal").bind(i))


func step_pedestal(pedestal_id: int) -> void:
	if is_solved:
		return

	if pedestal_id < 0 or pedestal_id >= 8:
		push_warning("PedestalPuzzleManager: Invalid pedestal id: " + str(pedestal_id))
		return

	match mode:
		PuzzleMode.SEQUENCE_OCTAGRAM:
			_process_sequence_step(pedestal_id)
		PuzzleMode.LIGHTS_OUT_C8:
			_process_c8_toggle(pedestal_id)


func _process_sequence_step(pedestal_id: int) -> void:
	if is_solved:
		return

	if current_step_index < target_sequence.size() and pedestal_id == target_sequence[current_step_index]:
		current_step_index += 1
		pedestal_state_updated.emit(pedestal_id, true)
		puzzle_step_advanced.emit(current_step_index, target_sequence.size())

		if current_step_index == target_sequence.size():
			is_solved = true
			puzzle_solved.emit({
				"reward_type": "SECRET_ARTIFACT",
				"bonus_xp": 2500,
				"unlocked_tech": "ancients_gateway"
			})
	else:
		puzzle_failed.emit(pedestal_id)
		current_step_index = 0
		_reset_all_pedestal_visuals()


func _process_c8_toggle(pedestal_id: int) -> void:
	if is_solved:
		return

	var left: int = (pedestal_id - 1 + 8) % 8
	var right: int = (pedestal_id + 1) % 8

	c8_state[pedestal_id] = 1 - c8_state[pedestal_id]
	c8_state[left] = 1 - c8_state[left]
	c8_state[right] = 1 - c8_state[right]

	c8_state_changed.emit(c8_state)
	_update_c8_visuals()

	# Win condition: all 8 nodes active (1)
	var win: bool = true
	for val in c8_state:
		if val == 0:
			win = false
			break

	if win:
		is_solved = true
		puzzle_solved.emit({
			"reward_type": "ANCIENT_CACHE",
			"minerals": 5000,
			"pedestal_bonus": 25,
			"unlocked_achievement": "ach_c8_mastery"
		})


## Sets up a guaranteed solvable initial state using deterministic seed (Task 9.10).
func setup_deterministic_initial_state(p_seed: int = 123456) -> void:
	match_seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	var solvable: Array[int] = F2Solver.generate_solvable_state(rng, 2)
	for i in range(8):
		c8_state[i] = solvable[i]
	is_solved = false
	_update_c8_visuals()


## Computes the minimal sequence of pedestal indices to solve current state (Task 9.8).
func get_solver_hints() -> Array[int]:
	var current: Array = []
	for val in c8_state:
		current.append(val)
	var res: Dictionary = F2Solver.solve_c8(current)
	var hints: Array[int] = []
	if res.get("solvable", false):
		var sol: Array = res.get("solution", [])
		for i in range(sol.size()):
			if sol[i] == 1:
				hints.append(i)
	return hints



func toggle_c8(pedestal_id: int) -> void:
	_process_c8_toggle(pedestal_id)


func get_pedestal_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for k in range(8):
		var angle: float = float(k) * (PI / 4.0)
		positions.append(Vector3(
			ring_radius * cos(angle),
			0.0,
			ring_radius * sin(angle)
		))
	return positions


func reset_puzzle() -> void:
	is_solved = false
	current_step_index = 0
	for i in range(8):
		c8_state[i] = 0
	_reset_all_pedestal_visuals()


func get_c8_state() -> PackedByteArray:
	return c8_state


func set_c8_state(new_state: PackedByteArray) -> void:
	if new_state.size() == 8:
		c8_state = new_state.duplicate()
		_update_c8_visuals()


func _reset_all_pedestal_visuals() -> void:
	for i in range(8):
		pedestal_state_updated.emit(i, false)
	for p in pedestals:
		if is_instance_valid(p) and p.has_method("set_active_state"):
			p.set_active_state(false)


func _update_c8_visuals() -> void:
	for i in range(8):
		pedestal_state_updated.emit(i, c8_state[i] == 1)
	for i in range(mini(pedestals.size(), 8)):
		var p: Node3D = pedestals[i]
		if is_instance_valid(p) and p.has_method("set_active_state"):
			p.set_active_state(c8_state[i] == 1)
