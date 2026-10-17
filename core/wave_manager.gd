class_name WaveManager
extends Node

## WaveManager - Handles round progression, spawn queueing, and wave state events.

@export var spawn_points: Array[Marker3D] = []
@export var spawn_interval: float = 0.6
@export var swarm_simulation: Node3D # SwarmSimulation reference

var zergling_data: EnemyData = preload("res://data/enemies/zergling_data.tres")
var roach_data: EnemyData = preload("res://data/enemies/roach_data.tres")
var enemy_scene: PackedScene = preload("res://entities/enemies/base_enemy_3d.tscn")

var current_wave: int = 0
var is_wave_in_progress: bool = false
var total_enemies_in_wave: int = 0
var enemies_alive: int = 0

var _spawn_queue: Array[EnemyData] = []
var _spawn_timer: float = 0.0
var _current_spawner_index: int = 0


func _ready() -> void:
	SignalBus.enemy_died.connect(_on_enemy_died)


func start_next_wave() -> void:
	if is_wave_in_progress:
		return

	current_wave += 1
	is_wave_in_progress = true
	_spawn_queue.clear()

	_build_wave_queue(current_wave)
	
	total_enemies_in_wave = _spawn_queue.size()
	enemies_alive = total_enemies_in_wave
	_spawn_timer = 0.1 # First spawn quickly

	SignalBus.wave_started.emit(current_wave, total_enemies_in_wave)
	SignalBus.wave_enemy_count_changed.emit(enemies_alive)


func _build_wave_queue(wave: int) -> void:
	var zergling_count: int = 0
	var roach_count: int = 0

	match wave:
		1:
			zergling_count = 8
			roach_count = 0
		2:
			zergling_count = 14
			roach_count = 2
		3:
			zergling_count = 20
			roach_count = 5
		_:
			# Scalable progression for Wave 4+
			zergling_count = 20 + (wave - 3) * 6
			roach_count = 5 + (wave - 3) * 3

	for i in range(zergling_count):
		_spawn_queue.append(zergling_data)
	for i in range(roach_count):
		_spawn_queue.append(roach_data)

	# Shuffle spawn order for natural swarm pacing
	_spawn_queue.shuffle()


func _process(delta: float) -> void:
	if not is_wave_in_progress:
		return

	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			var data: EnemyData = _spawn_queue.pop_front()
			_spawn_enemy(data)


func _spawn_enemy(data: EnemyData) -> void:
	if spawn_points.is_empty():
		return

	var spawner: Marker3D = spawn_points[_current_spawner_index]
	_current_spawner_index = (_current_spawner_index + 1) % spawn_points.size()

	# Slight positional jitter around spawn marker to avoid exact overlaps
	var jitter: Vector3 = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
	var spawn_pos: Vector3 = spawner.global_position + jitter

	if swarm_simulation != null and swarm_simulation.has_method("spawn_unit"):
		var arch_id: int = 0
		if data and data.enemy_name.to_lower().contains("roach"):
			arch_id = 1
		swarm_simulation.spawn_unit(arch_id, spawn_pos)
	elif enemy_scene:
		var enemy: BaseEnemy3D = enemy_scene.instantiate() as BaseEnemy3D
		enemy.enemy_data = data
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = spawn_pos


func on_swarm_unit_died(_reward: int = 5) -> void:
	if not is_wave_in_progress:
		return

	enemies_alive = max(0, enemies_alive - 1)
	SignalBus.wave_enemy_count_changed.emit(enemies_alive)

	if enemies_alive == 0 and _spawn_queue.is_empty():
		is_wave_in_progress = false
		SignalBus.wave_completed.emit(current_wave)


func _on_enemy_died(_enemy: Node, _reward: int) -> void:
	if not is_wave_in_progress:
		return

	enemies_alive = max(0, enemies_alive - 1)
	SignalBus.wave_enemy_count_changed.emit(enemies_alive)

	if enemies_alive == 0 and _spawn_queue.is_empty():
		is_wave_in_progress = false
		SignalBus.wave_completed.emit(current_wave)
