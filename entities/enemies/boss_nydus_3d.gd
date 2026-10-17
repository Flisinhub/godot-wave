class_name BossNydus3D
extends CharacterBody3D

## BossNydus3D - Hell's Gate Nydus Boss unsealed by HellsGateZone3D.
## Colossal subterranean entity with heavy chitin armor (20 flat armor),
## periodic corrosive bile bursts, and autonomous swarm minion spawning.

signal nydus_minions_spawned(count: int)
signal bile_burst_launched(target_pos: Vector3)
signal boss_defeated()

@export var max_health: float = 8000.0
@export var flat_armor: float = 20.0
@export var attack_damage: float = 40.0
@export var bile_damage: float = 85.0
@export var bile_radius: float = 5.0
@export var bile_cooldown: float = 4.0
@export var spawn_cadence: float = 6.0
@export var minions_per_spawn: int = 4
@export var kill_reward: int = 2500

var current_health: float = 8000.0
var _bile_timer: float = 2.0
var _spawn_timer: float = 3.0
var current_target: Node3D = null


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("nydus_boss")

	current_health = max_health
	_setup_visual_proxy()


func _setup_visual_proxy() -> void:
	if has_node("VisualRoot"):
		return

	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)

	if DisplayServer.get_name() != "headless":
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MawMesh"
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = 2.2
		cylinder_mesh.bottom_radius = 3.0
		cylinder_mesh.height = 5.5
		mesh_instance.mesh = cylinder_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.05, 0.3) # Abyssal violet
		mat.roughness = 0.8
		mesh_instance.material_override = mat
		root.add_child(mesh_instance)


func _physics_process(delta: float) -> void:
	_bile_timer = max(0.0, _bile_timer - delta)
	_spawn_timer = max(0.0, _spawn_timer - delta)

	# Corrosive Bile Burst
	if _bile_timer <= 0.0:
		_find_best_target()
		if is_instance_valid(current_target):
			_bile_timer = bile_cooldown
			_launch_bile_burst(current_target.global_position)

	# Minion Swarm Spawning
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_cadence
		_spawn_minion_wave()


func _launch_bile_burst(target_pos: Vector3) -> void:
	bile_burst_launched.emit(target_pos)

	# AoE spell damage to allies near target impact point
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and ally is Node3D:
			var d: float = target_pos.distance_to(ally.global_position)
			if d <= bile_radius:
				if ally.has_method("take_damage"):
					ally.take_damage(bile_damage)


func _spawn_minion_wave() -> void:
	nydus_minions_spawned.emit(minions_per_spawn)

	# Attempt to instantiate base enemy or spawn placeholder minion nodes
	var base_enemy_scene = load("res://entities/enemies/base_enemy_3d.tscn")
	for i in range(minions_per_spawn):
		var angle: float = float(i) * (TAU / float(minions_per_spawn))
		var offset := Vector3(cos(angle) * 3.5, 0.0, sin(angle) * 3.5)
		var spawn_pos: Vector3 = global_position + offset

		if base_enemy_scene:
			var minion: Node3D = base_enemy_scene.instantiate() as Node3D
			if get_tree() and get_tree().current_scene:
				get_tree().current_scene.add_child(minion)
			else:
				add_child(minion)
			minion.global_position = spawn_pos


func _find_best_target() -> void:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("heroes")
	var nearest: Node3D = null
	var min_dist: float = 30.0

	for h in heroes:
		if is_instance_valid(h) and h is Node3D:
			var d: float = global_position.distance_to(h.global_position)
			if d < min_dist:
				min_dist = d
				nearest = h as Node3D

	if not nearest:
		var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
		for a in allies:
			if is_instance_valid(a) and a is Node3D:
				var d: float = global_position.distance_to(a.global_position)
				if d < min_dist:
					min_dist = d
					nearest = a as Node3D

	current_target = nearest


func take_damage(amount: float) -> void:
	var mitigated: float = max(1.0, amount - flat_armor)
	current_health = max(0.0, current_health - mitigated)
	if current_health <= 0.0:
		die()


func die() -> void:
	boss_defeated.emit()
	if SignalBus.has_signal("enemy_died"):
		SignalBus.enemy_died.emit(self, kill_reward)
	queue_free()
