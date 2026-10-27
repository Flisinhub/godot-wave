class_name BossHybrid3D
extends CharacterBody3D

## BossHybrid3D - Psionic Apex Entity Event Boss
## 10,000 HP + 4,000 Shield, 8 flat armor, 4,000 mineral bounty, 1,000 XP bounty.
## Dual-layer EHP pool (14,000 Total EHP). Shields absorb damage 1:1; surplus penetrates into HP.
## Abilities:
## - Psionic Shockwave (120 spell dmg, 40 energy drain, 40% Heroic AoE penalty -> 72 net dmg).
## - Graviton Vortex (3.0s hero pull and immobilization).
## - Swarm Rift (summons 6 Void Zerglings & 2 Void Hydralisks).
## Encapsulates all rendering strictly under $VisualRoot (Decoupled VisualRoot Invariant).

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

signal boss_spawned(boss_name: String, max_hp: float, max_shields: float)
signal boss_health_changed(current_hp: float, current_shields: float, phase: int)
signal boss_ability_casting(ability_name: String, windup_duration: float)
signal boss_died()

@export var max_health: float = 10000.0
@export var max_shields: float = 4000.0
@export var flat_armor: float = 8.0
@export var kill_reward: int = 4000
@export var xp_reward: int = 1000
@export var boss_name: String = "Hybrid Dominator"

@export var move_speed: float = 3.8
@export var attack_damage: float = 75.0
@export var attack_cooldown: float = 1.2
@export var attack_range: float = 3.5

# Ability Parameters
@export var shockwave_cooldown: float = 14.0
@export var shockwave_damage: float = 120.0
@export var shockwave_energy_drain: float = 40.0
@export var shockwave_radius: float = 10.0

@export var vortex_cooldown: float = 18.0
@export var vortex_duration: float = 3.0
@export var vortex_radius: float = 8.0

@export var rift_cooldown: float = 25.0

# Runtime State
var current_health: float = 10000.0
var current_shields: float = 4000.0
var current_phase: int = 1
var is_dead: bool = false

# Timers
var _attack_timer: float = 0.0
var _shockwave_timer: float = 4.0
var _vortex_timer: float = 8.0
var _rift_timer: float = 12.0
var _casting_timer: float = 0.0
var _target_search_timer: float = 0.0
var current_target: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _init() -> void:
	current_health = max_health
	current_shields = max_shields
	current_phase = 1


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("hybrid")

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
		box.size = Vector3(3.2, 3.8, 3.2)
		mesh_instance.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.05, 0.22, 1.0)
		mat.metallic = 0.5
		mat.roughness = 0.35
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.1, 0.9, 1.0)
		mat.emission_energy_multiplier = 1.8
		mesh_instance.material_override = mat
		mesh_instance.position = Vector3(0.0, 1.9, 0.0)
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
	_shockwave_timer = maxf(0.0, _shockwave_timer - delta)
	_vortex_timer = maxf(0.0, _vortex_timer - delta)
	_rift_timer = maxf(0.0, _rift_timer - delta)

	_target_search_timer -= delta
	if _target_search_timer <= 0.0:
		_target_search_timer = 0.6
		_find_best_target()

	# Ability Check 1: Psionic Shockwave
	if _shockwave_timer <= 0.0 and is_instance_valid(current_target):
		var dist: float = global_position.distance_to(current_target.global_position)
		if dist <= shockwave_radius + 2.0:
			execute_psionic_shockwave()
			return

	# Ability Check 2: Graviton Vortex
	if _vortex_timer <= 0.0 and is_instance_valid(current_target):
		var dist_v: float = global_position.distance_to(current_target.global_position)
		if dist_v <= vortex_radius + 4.0:
			execute_graviton_vortex()
			return

	# Ability Check 3: Swarm Rift
	if _rift_timer <= 0.0:
		execute_swarm_rift()
		return

	if not is_instance_valid(current_target):
		_stop_movement(delta)
		return

	var d: float = global_position.distance_to(current_target.global_position)
	if d <= attack_range:
		_stop_movement(delta)
		_look_at_target(current_target.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_melee_attack()
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


func _perform_melee_attack() -> void:
	if not is_instance_valid(current_target):
		return
	if current_target.has_method("take_damage_context"):
		current_target.take_damage_context(attack_damage, CombatTypes.DamageType.PHYSICAL, false, 0)
	elif current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)


## Psionic Shockwave - 120 spell dmg, 40 energy drain, 40% Heroic AoE penalty (72 net dmg)
func execute_psionic_shockwave() -> void:
	_shockwave_timer = shockwave_cooldown
	_casting_timer = 1.5
	boss_ability_casting.emit("Psionic Shockwave", 1.5)
	_play_sfx_3d(&"orbital_bombardment", global_position)

	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("allies"))
	targets.append_array(get_tree().get_nodes_in_group("structures"))

	for t in targets:
		if is_instance_valid(t) and t is Node3D:
			var dist: float = global_position.distance_to(t.global_position)
			if dist <= shockwave_radius:
				var is_heroic: bool = t.is_in_group("heroes") or (t.get("hero_data") != null)
				var hit = SFECombatEngine.calculate_damage(
					shockwave_damage,
					CombatTypes.DamageType.SPELL,
					0.0, # Spell damage bypasses flat armor
					0,
					CombatTypes.StructureType.NONE,
					is_heroic,
					true # is_aoe
				)
				if t.has_method("take_damage"):
					t.take_damage(hit.damage_dealt)

				# Energy Drain
				if is_heroic:
					if "current_energy" in t:
						t.current_energy = maxf(0.0, t.current_energy - shockwave_energy_drain)
					elif t.has_method("consume_energy"):
						t.consume_energy(shockwave_energy_drain)


## Graviton Vortex - Pulls allies toward vortex center and immobilizes for 3.0s
func execute_graviton_vortex() -> void:
	_vortex_timer = vortex_cooldown
	_casting_timer = 1.0
	boss_ability_casting.emit("Graviton Vortex", 1.0)
	_play_sfx_3d(&"explosion", global_position)

	var center: Vector3 = global_position
	if is_instance_valid(current_target):
		center = current_target.global_position

	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			var dist: float = center.distance_to(a.global_position)
			if dist <= vortex_radius:
				# Pull toward center
				var pull_dir: Vector3 = (center - a.global_position).normalized()
				if "velocity" in a:
					a.velocity += pull_dir * 8.0
				# Immobilize
				if a.has_method("apply_stun"):
					a.apply_stun(vortex_duration)
				elif "is_stunned" in a:
					a.is_stunned = true


## Swarm Rift - Tears open a void rift summoning 6 Void Zerglings & 2 Void Hydralisks
func execute_swarm_rift() -> void:
	_rift_timer = rift_cooldown
	_casting_timer = 2.0
	boss_ability_casting.emit("Swarm Rift", 2.0)
	_play_sfx_3d(&"zerg_death", global_position)

	var swarm_sim = get_tree().get_first_node_in_group("swarm_simulation")
	if not swarm_sim:
		var root = get_tree().current_scene
		if root:
			swarm_sim = root.get_node_or_null("SwarmSimulation")

	if swarm_sim and swarm_sim.has_method("spawn_wave"):
		swarm_sim.spawn_wave(0, 6, global_position, 3.5)
		swarm_sim.spawn_wave(3, 2, global_position + Vector3(0, 0, 2), 2.5)


func take_damage_context(raw_dmg: float, dmg_type: int, is_heroic: bool, _piercing: int = 0) -> float:
	return take_damage(raw_dmg, dmg_type, is_heroic)


## Shield Absorption and Health Penetration Rules:
## 1. Shields absorb 1:1 without flat armor mitigation.
## 2. Surplus penetrates into HP.
## 3. Physical surplus is mitigated by 8 flat armor; Spell surplus bypasses flat armor.
func take_damage(amount: float, dmg_type: int = CombatTypes.DamageType.PHYSICAL, is_heroic: bool = false, is_aoe: bool = false) -> float:
	if is_dead:
		return 0.0

	var total_absorbed: float = 0.0
	var total_damage_dealt: float = 0.0

	if current_shields > 0.0:
		var absorb_amount: float = minf(current_shields, amount)
		current_shields -= absorb_amount
		total_absorbed = absorb_amount
		var surplus: float = amount - absorb_amount

		if surplus > 0.0:
			var armor_to_apply: float = flat_armor if dmg_type == CombatTypes.DamageType.PHYSICAL else 0.0
			var hp_hit = SFECombatEngine.calculate_damage(
				surplus,
				dmg_type,
				armor_to_apply,
				0,
				CombatTypes.StructureType.NONE,
				is_heroic,
				is_aoe
			)
			current_health = maxf(0.0, current_health - hp_hit.damage_dealt)
			total_damage_dealt = hp_hit.damage_dealt
	else:
		var armor_to_apply: float = flat_armor if dmg_type == CombatTypes.DamageType.PHYSICAL else 0.0
		var hp_hit = SFECombatEngine.calculate_damage(
			amount,
			dmg_type,
			armor_to_apply,
			0,
			CombatTypes.StructureType.NONE,
			is_heroic,
			is_aoe
		)
		current_health = maxf(0.0, current_health - hp_hit.damage_dealt)
		total_damage_dealt = hp_hit.damage_dealt

	if current_shields <= 0.0 and current_phase == 1:
		current_phase = 2

	boss_health_changed.emit(current_health, current_shields, current_phase)

	if current_health <= 0.0:
		die()

	return total_absorbed + total_damage_dealt


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

	var ccs: Array[Node] = get_tree().get_nodes_in_group("command_centers")
	if not ccs.is_empty() and is_instance_valid(ccs[0]):
		current_target = ccs[0] as Node3D


func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	current_shields = 0.0
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
