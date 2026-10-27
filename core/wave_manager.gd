class_name WaveManager
extends Node

## WaveManager - Handles round progression, 10+ wave schedules, specialized strain spawning,
## and boss encounter climaxes (Wave 5 Brutalisk, Wave 10 Hybrid Dominator).

signal boss_spawn_requested(boss_scene: PackedScene, spawn_pos: Vector3)

@export var spawn_points: Array[Marker3D] = []
@export var spawn_interval: float = 0.6
@export var swarm_simulation: Node3D # SwarmSimulation reference

var zergling_data: EnemyData = preload("res://data/enemies/zergling_data.tres")
var roach_data: EnemyData = preload("res://data/enemies/roach_data.tres")
var enemy_scene: PackedScene = preload("res://entities/enemies/base_enemy_3d.tscn")

var baneling_data: EnemyData
var hydralisk_data: EnemyData

var boss_brutalisk_scene: PackedScene = preload("res://entities/enemies/boss_brutalisk_3d.tscn")
var boss_hybrid_scene: PackedScene = preload("res://entities/enemies/boss_hybrid_3d.tscn")

var current_wave: int = 0
var is_wave_in_progress: bool = false
var total_enemies_in_wave: int = 0
var enemies_alive: int = 0

var _spawn_queue: Array[EnemyData] = []
var _spawn_timer: float = 0.0
var _current_spawner_index: int = 0


func _init() -> void:
	_init_strain_enemy_data()


func _ready() -> void:
	SignalBus.enemy_died.connect(_on_enemy_died)
	_init_strain_enemy_data()


func _init_strain_enemy_data() -> void:
	if baneling_data == null:
		baneling_data = EnemyData.new()
		baneling_data.enemy_name = "Baneling"
		baneling_data.max_health = 30.0
		baneling_data.move_speed = 8.5
		baneling_data.attack_damage = 40.0
		baneling_data.attack_range = 1.4
		baneling_data.attack_cooldown = 0.1
		baneling_data.kill_reward = 8

	if hydralisk_data == null:
		hydralisk_data = EnemyData.new()
		hydralisk_data.enemy_name = "Hydralisk"
		hydralisk_data.max_health = 80.0
		hydralisk_data.move_speed = 4.8
		hydralisk_data.attack_damage = 16.0
		hydralisk_data.attack_range = 9.0
		hydralisk_data.attack_cooldown = 0.85
		hydralisk_data.kill_reward = 12


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

	# Check for Event Boss Encounters (Wave 5: Brutalisk, Wave 10: Hybrid Dominator)
	if current_wave == 5 or current_wave == 10:
		_spawn_wave_boss(current_wave)

	SignalBus.wave_started.emit(current_wave, total_enemies_in_wave)
	SignalBus.wave_enemy_count_changed.emit(enemies_alive)


func _build_wave_queue(wave: int) -> void:
	_init_strain_enemy_data()

	var zergling_count: int = 0
	var roach_count: int = 0
	var baneling_count: int = 0
	var hydralisk_count: int = 0

	match wave:
		1:
			# Early Zerglings only (8 units)
			zergling_count = 8
			roach_count = 0
			baneling_count = 0
			hydralisk_count = 0
		2:
			# Roaches introduced (16 units)
			zergling_count = 14
			roach_count = 2
			baneling_count = 0
			hydralisk_count = 0
		3:
			# Banelings introduced (26 units: 18 Zerglings, 4 Roaches, 4 Banelings)
			zergling_count = 18
			roach_count = 4
			baneling_count = 4
			hydralisk_count = 0
		4:
			# Hydralisks introduced (36 units)
			zergling_count = 22
			roach_count = 6
			baneling_count = 4
			hydralisk_count = 4
		5:
			# Brutalisk Climax Wave (46 swarm units + Boss Brutalisk)
			zergling_count = 26
			roach_count = 8
			baneling_count = 6
			hydralisk_count = 6
		6:
			# Escalating Swarm Assault (58 units)
			zergling_count = 32
			roach_count = 10
			baneling_count = 8
			hydralisk_count = 8
		7:
			# Heavy Siege (70 units)
			zergling_count = 38
			roach_count = 12
			baneling_count = 10
			hydralisk_count = 10
		8:
			# Breaching Swarm (84 units)
			zergling_count = 44
			roach_count = 15
			baneling_count = 12
			hydralisk_count = 13
		9:
			# Mass Artillery & Bio-Bombs (99 units)
			zergling_count = 50
			roach_count = 18
			baneling_count = 15
			hydralisk_count = 16
		10:
			# Hybrid Dominator Climax Wave (116 swarm units + Boss Hybrid Dominator)
			zergling_count = 56
			roach_count = 22
			baneling_count = 18
			hydralisk_count = 20
		_:
			# Scalable progression for Wave 11+
			var extra: int = wave - 10
			zergling_count = 56 + extra * 8
			roach_count = 22 + extra * 4
			baneling_count = 18 + extra * 3
			hydralisk_count = 20 + extra * 3

	for i in range(zergling_count):
		_spawn_queue.append(zergling_data)
	for i in range(roach_count):
		_spawn_queue.append(roach_data)
	for i in range(baneling_count):
		_spawn_queue.append(baneling_data)
	for i in range(hydralisk_count):
		_spawn_queue.append(hydralisk_data)

	# Shuffle spawn order for organic swarm pacing
	_spawn_queue.shuffle()


func _spawn_wave_boss(wave: int) -> void:
	var boss_scene: PackedScene = null
	if wave == 5:
		boss_scene = boss_brutalisk_scene
	elif wave == 10:
		boss_scene = boss_hybrid_scene

	if boss_scene == null:
		return

	var spawn_pos := Vector3(25.0, 0.0, -25.0)
	if not spawn_points.is_empty():
		spawn_pos = spawn_points[0].global_position + Vector3(0.0, 0.0, 2.0)

	boss_spawn_requested.emit(boss_scene, spawn_pos)

	if is_inside_tree():
		var boss_node: Node3D = boss_scene.instantiate() as Node3D
		if boss_node:
			var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
			if parent_node:
				parent_node.add_child(boss_node)
				boss_node.global_position = spawn_pos
				# Increment wave counts to track boss
				total_enemies_in_wave += 1
				enemies_alive += 1
				SignalBus.wave_enemy_count_changed.emit(enemies_alive)

				if boss_node.has_signal("boss_died"):
					boss_node.boss_died.connect(func(): on_swarm_unit_died(boss_node.get("kill_reward") if "kill_reward" in boss_node else 2500))

				# Bind to BossHealthBarUI if in tree
				var boss_ui = get_tree().get_first_node_in_group("boss_ui")
				if not boss_ui and parent_node.has_node("BossHealthBarUI"):
					boss_ui = parent_node.get_node("BossHealthBarUI")
				if boss_ui and boss_ui.has_method("bind_boss"):
					boss_ui.bind_boss(boss_node)


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
		if data:
			var n: String = data.enemy_name.to_lower()
			if n.contains("roach"):
				arch_id = 1
			elif n.contains("baneling"):
				arch_id = 2
			elif n.contains("hydralisk") or n.contains("hydra"):
				arch_id = 3
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
