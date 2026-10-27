class_name BossBrutalisk3D
extends CharacterBody3D

## BossBrutalisk3D - Multi-phase Hive Leviathan Event Boss
## 8,000 HP, 12 flat armor, 2,500 mineral bounty, 500 XP bounty.
## Phase 1 (100%–66% HP): Ground Slam (seismic shockwave, 180 dmg, 1.5s stun).
## Phase 2 (66%–33% HP): Acid Nova + Brood Eruption (spawns 4 Banelings).
## Phase 3 (<33% HP): Cataclysmic Frenzy (+50% move/attack speed) + Corrosive Miasma (15 dmg/s aura).
## Encapsulates all rendering strictly under $VisualRoot (Decoupled VisualRoot Invariant).

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

signal boss_spawned(boss_name: String, max_hp: float, max_shields: float)
signal boss_health_changed(current_hp: float, current_shields: float, phase: int)
signal boss_ability_casting(ability_name: String, windup_duration: float)
signal boss_died()

@export var max_health: float = 8000.0
@export var max_shields: float = 0.0
@export var flat_armor: float = 12.0
@export var kill_reward: int = 2500
@export var xp_reward: int = 500
@export var boss_name: String = "Brutalisk"

@export var move_speed: float = 3.6
@export var attack_damage: float = 65.0
@export var attack_cooldown: float = 1.5
@export var cleave_radius: float = 4.2

# Ability Parameters
@export var slam_cooldown: float = 12.0
@export var slam_damage: float = 180.0
@export var slam_radius: float = 6.0
@export var slam_stun_duration: float = 1.5

@export var acid_nova_cooldown: float = 10.0
@export var acid_nova_damage: float = 90.0
@export var acid_nova_radius: float = 12.0

@export var miasma_damage_per_sec: float = 15.0
@export var miasma_radius: float = 7.0

# Runtime Health & Phase State
var current_health: float = 8000.0
var current_shields: float = 0.0
var current_phase: int = 1
var is_dead: bool = false
var banelings_spawned: int = 0
var miasma_active: bool = false

# Phase Thresholds
var phase_2_threshold: float = 5280.0 # 8000 * 0.66
var phase_3_threshold: float = 2640.0 # 8000 * 0.33

# AI & Timers
var _attack_timer: float = 0.0
var _slam_timer: float = 5.0
var _nova_timer: float = 6.0
var _miasma_accumulator: float = 0.0
var _target_search_timer: float = 0.0
var _casting_timer: float = 0.0
var current_target: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _init() -> void:
	current_health = max_health
	current_shields = max_shields
	current_phase = 1


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("brutalisk")

	_ensure_visual_root()
	_find_best_target()
	boss_spawned.emit(boss_name, max_health, max_shields)


func _ensure_visual_root() -> void:
	if has_node("VisualRoot"):
		return
	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)

	if DisplayServer.get_name() != "headless":
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "BodyMesh"
		var box := BoxMesh.new()
		box.size = Vector3(4.0, 3.6, 5.0)
		mesh_instance.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.06, 0.1, 1.0)
		mat.metallic = 0.35
		mat.roughness = 0.55
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.2, 0.05, 1.0)
		mat.emission_energy_multiplier = 1.2
		mesh_instance.material_override = mat
		mesh_instance.position = Vector3(0.0, 1.8, 0.0)
		root.add_child(mesh_instance)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Ability casting lock
	if _casting_timer > 0.0:
		_casting_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)
	_slam_timer = maxf(0.0, _slam_timer - delta)
	if current_phase >= 2:
		_nova_timer = maxf(0.0, _nova_timer - delta)

	# Corrosive Miasma (Phase 3 continuous tick)
	if miasma_active:
		_miasma_accumulator += delta
		if _miasma_accumulator >= 0.5:
			_tick_corrosive_miasma(_miasma_accumulator)
			_miasma_accumulator = 0.0

	# Target search
	_target_search_timer -= delta
	if _target_search_timer <= 0.0:
		_target_search_timer = 0.6
		_find_best_target()

	# Ability Check: Ground Slam (Phase 1+)
	if _slam_timer <= 0.0 and is_instance_valid(current_target):
		var dist_to_tgt: float = global_position.distance_to(current_target.global_position)
		if dist_to_tgt <= slam_radius + 2.0:
			execute_ground_slam()
			return

	# Ability Check: Acid Nova (Phase 2+)
	if current_phase >= 2 and _nova_timer <= 0.0 and is_instance_valid(current_target):
		execute_acid_nova()
		return

	if not is_instance_valid(current_target):
		_stop_movement(delta)
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	if dist <= cleave_radius:
		_stop_movement(delta)
		_look_at_target(current_target.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_cleave_attack()
	else:
		_navigate_towards(current_target.global_position, delta)


func _navigate_towards(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_look_at_target(target_pos, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _stop_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)
	move_and_slide()


func _look_at_target(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		var target_angle_y: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 6.0)


func _perform_cleave_attack() -> void:
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")

	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			if global_position.distance_to(a.global_position) <= cleave_radius:
				if a.has_method("take_damage_context"):
					a.take_damage_context(attack_damage, CombatTypes.DamageType.PHYSICAL, false, 0)
				elif a.has_method("take_damage"):
					a.take_damage(attack_damage)

	for s in structures:
		if is_instance_valid(s) and s is Node3D:
			if global_position.distance_to(s.global_position) <= cleave_radius + 1.5:
				if s.has_method("take_damage_context"):
					s.take_damage_context(attack_damage, CombatTypes.DamageType.PHYSICAL, false, 0)
				elif s.has_method("take_damage"):
					s.take_damage(attack_damage)


## Ground Slam - Phase 1 AoE shockwave dealing 180 dmg and stunning non-hero defenders for 1.5s
func execute_ground_slam(override_dmg: float = -1.0) -> void:
	_slam_timer = slam_cooldown
	_casting_timer = 1.5
	boss_ability_casting.emit("Ground Slam", 1.5)

	var effective_damage: float = override_dmg if override_dmg > 0.0 else slam_damage

	# Sound & Telegraph
	_play_sfx_3d(&"explosion", global_position)

	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			var d: float = global_position.distance_to(a.global_position)
			if d <= slam_radius:
				var is_heroic: bool = a.is_in_group("heroes") or (a.get("hero_data") != null)
				var hit = SFECombatEngine.calculate_damage(
					effective_damage,
					CombatTypes.DamageType.PHYSICAL,
					a.get("flat_armor") if "flat_armor" in a else 1.0,
					0,
					CombatTypes.StructureType.NONE,
					is_heroic,
					true
				)
				if a.has_method("take_damage"):
					a.take_damage(hit.damage_dealt)

				# Non-hero units are stunned
				if not is_heroic:
					if a.has_method("apply_stun"):
						a.apply_stun(slam_stun_duration)
					elif "is_stunned" in a:
						a.is_stunned = true


## Acid Nova - Phase 2 ring of corrosive acid globules dealing 90 spell damage and -3 flat armor debuff
func execute_acid_nova() -> void:
	_nova_timer = acid_nova_cooldown
	_casting_timer = 1.0
	boss_ability_casting.emit("Acid Nova", 1.0)
	_play_sfx_3d(&"roach_spit", global_position)

	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			var d: float = global_position.distance_to(a.global_position)
			if d <= acid_nova_radius:
				var hit = SFECombatEngine.calculate_damage(
					acid_nova_damage,
					CombatTypes.DamageType.SPELL,
					0.0,
					0,
					CombatTypes.StructureType.NONE,
					a.is_in_group("heroes"),
					true
				)
				if a.has_method("take_damage"):
					a.take_damage(hit.damage_dealt)
				if a.has_method("apply_armor_debuff"):
					a.apply_armor_debuff(3.0, 6.0)


## Brood Eruption - Spawns 4 live Banelings
func execute_brood_eruption() -> void:
	banelings_spawned += 4
	_play_sfx_3d(&"baneling_explode", global_position)

	var swarm_sim = get_tree().get_first_node_in_group("swarm_simulation")
	if not swarm_sim:
		var root = get_tree().current_scene
		if root:
			swarm_sim = root.get_node_or_null("SwarmSimulation")

	if swarm_sim and swarm_sim.has_method("spawn_wave"):
		swarm_sim.spawn_wave(2, 4, global_position, 3.0)


## Corrosive Miasma - Continuous toxic gas dealing 15 spell dmg/s in 7.0m radius
func _tick_corrosive_miasma(dt: float) -> void:
	var tick_damage: float = miasma_damage_per_sec * dt
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("allies"))
	targets.append_array(get_tree().get_nodes_in_group("structures"))

	for t in targets:
		if is_instance_valid(t) and t is Node3D:
			if global_position.distance_to(t.global_position) <= miasma_radius:
				var hit = SFECombatEngine.calculate_damage(
					tick_damage,
					CombatTypes.DamageType.SPELL,
					0.0,
					0,
					CombatTypes.StructureType.NONE,
					t.is_in_group("heroes"),
					true
				)
				if t.has_method("take_damage"):
					t.take_damage(hit.damage_dealt)


func take_damage_context(raw_dmg: float, dmg_type: int, is_heroic: bool, _piercing: int = 0) -> float:
	return take_damage(raw_dmg, dmg_type, is_heroic)


## Core damage intake with Armor mitigation and Burst Phase Skip Invariant
func take_damage(amount: float, dmg_type: int = CombatTypes.DamageType.PHYSICAL, is_heroic: bool = false, is_aoe: bool = false) -> float:
	if is_dead:
		return 0.0

	var res = SFECombatEngine.calculate_damage(
		amount,
		dmg_type,
		flat_armor,
		0,
		CombatTypes.StructureType.NONE,
		is_heroic,
		is_aoe
	)

	var net_dmg: float = res.damage_dealt
	var prev_hp: float = current_health
	current_health = maxf(0.0, current_health - net_dmg)

	# Burst phase skip invariant: Single high burst (e.g. 6400 to 1600 HP)
	# triggers Phase 2 Brood Eruption AND Phase 3 Frenzy sequentially
	if prev_hp > phase_2_threshold and current_health <= phase_2_threshold:
		_trigger_phase_2()

	if prev_hp > phase_3_threshold and current_health <= phase_3_threshold:
		_trigger_phase_3()

	boss_health_changed.emit(current_health, current_shields, current_phase)

	if current_health <= 0.0:
		die()

	return net_dmg


func _trigger_phase_2() -> void:
	current_phase = 2
	execute_brood_eruption()


func _trigger_phase_3() -> void:
	current_phase = 3
	# Cataclysmic Frenzy
	move_speed = 3.6 * 1.5 # 5.4 m/s
	attack_cooldown = 0.75 # +50% attack speed
	miasma_active = true


func _find_best_target() -> void:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("heroes")
	var nearest: Node3D = null
	var min_dist: float = 35.0

	for h in heroes:
		if is_instance_valid(h) and h is Node3D:
			var d: float = global_position.distance_to(h.global_position)
			if d < min_dist:
				min_dist = d
				nearest = h as Node3D

	if nearest:
		current_target = nearest
		return

	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	min_dist = INF
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			var d: float = global_position.distance_to(a.global_position)
			if d < min_dist:
				min_dist = d
				nearest = a as Node3D

	if nearest:
		current_target = nearest
		return

	# Default to command center / structures
	var ccs: Array[Node] = get_tree().get_nodes_in_group("command_centers")
	if not ccs.is_empty() and is_instance_valid(ccs[0]):
		current_target = ccs[0] as Node3D


func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	boss_health_changed.emit(0.0, 0.0, current_phase)
	boss_died.emit()

	var bus = _get_signal_bus()
	if bus and bus.has_signal("enemy_died"):
		bus.enemy_died.emit(self, kill_reward)
	queue_free()


func _play_sfx_3d(sfx_name: StringName, pos: Vector3) -> void:
	var sfx = Engine.get_singleton("SFXManager") if Engine.has_singleton("SFXManager") else null
	if not sfx and has_node("/root/SFXManager"):
		sfx = get_node("/root/SFXManager")
	if sfx and sfx.has_method("play_sfx_3d"):
		sfx.play_sfx_3d(sfx_name, pos)


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var t := get_tree()
	if t and t.root and t.root.has_node("SignalBus"):
		return t.root.get_node("SignalBus")
	return null
