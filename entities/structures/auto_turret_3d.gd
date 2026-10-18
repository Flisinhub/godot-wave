class_name AutoTurret3D
extends StaticBody3D

## AutoTurret3D - Automated 360-Degree Twin-Gatling Perimeter Defense Turret.
## Implements Feature 8 of SFE5 Phase 2 (Milestone M2).
## Prioritizes high-threat enemies (Banelings > Bosses > Hydras > Roaches > Zerglings),
## scales stats via ArmoryUpgradeManager, and registers dynamic obstacles in SwarmFlowField.

signal turret_fired(target: Variant, damage_dealt: float)
signal turret_damaged(current_hp: float, max_hp: float)
signal turret_destroyed(turret: AutoTurret3D)

const TURRET_COST: int = 125
const MAX_ACTIVE_TURRETS: int = 6
const BASE_HEALTH: float = 350.0
const BASE_FLAT_ARMOR: float = 2.0
const BASE_DAMAGE: float = 14.0
const BASE_ATTACK_RANGE: float = 10.5
const BASE_ATTACK_INTERVAL: float = 0.35
const FLOW_FIELD_RADIUS: float = 1.2
const FLOW_FIELD_COST: int = 255

@export var max_health: float = BASE_HEALTH
@export var flat_armor: float = BASE_FLAT_ARMOR
@export var attack_damage: float = BASE_DAMAGE
@export var attack_range: float = BASE_ATTACK_RANGE
@export var attack_interval: float = BASE_ATTACK_INTERVAL
@export var tracking_speed: float = 16.0

var current_health: float = BASE_HEALTH
var current_target: Variant = null
var _attack_timer: float = 0.0
var _shot_count: int = 0
var _is_headless: bool = false
var _is_flow_field_registered: bool = false

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var health_bar: Node = get_node_or_null("HealthBar3D")

var turret_head: Node3D = null
var muzzle_left: Marker3D = null
var muzzle_right: Marker3D = null
var anim_player: AnimationPlayer = null


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	add_to_group("structures")
	add_to_group("turrets")
	add_to_group("allies")

	current_health = max_health
	if health_bar != null and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

	_setup_visual_components()
	_register_flow_field_obstacle()


func _exit_tree() -> void:
	_unregister_flow_field_obstacle()


func _setup_visual_components() -> void:
	if visual_root == null:
		return

	turret_head = visual_root.get_node_or_null("TurretHead")
	if turret_head == null:
		turret_head = visual_root.get_node_or_null("AutoTurret/TurretHead")

	if turret_head != null:
		muzzle_left = turret_head.get_node_or_null("MuzzleLeft") as Marker3D
		muzzle_right = turret_head.get_node_or_null("MuzzleRight") as Marker3D

	anim_player = visual_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = visual_root.get_node_or_null("AutoTurret/AnimationPlayer") as AnimationPlayer

	if anim_player != null and anim_player.has_animation("idle") and not _is_headless:
		anim_player.play("idle")


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)

	if not _is_target_valid(current_target):
		current_target = _acquire_best_target()

	if current_target != null:
		var target_pos: Vector3 = _get_target_position(current_target)
		_track_yaw(target_pos, delta)

		if _attack_timer <= 0.0:
			_attack_timer = attack_interval
			_fire_at(current_target, target_pos)
	else:
		_idle_scan(delta)


func _is_target_valid(target: Variant) -> bool:
	if target == null:
		return false
	if target is Node3D:
		var node: Node3D = target as Node3D
		if not is_instance_valid(node):
			return false
		var hp: float = float(node.get("current_health")) if "current_health" in node else 1.0
		if hp <= 0.0:
			return false
		return global_position.distance_to(node.global_position) <= attack_range
	elif target is int:
		var target_idx: int = target as int
		var swarm_sim: Variant = _get_swarm_simulation()
		if swarm_sim and swarm_sim.get("swarm_data"):
			var swarm_data: Variant = swarm_sim.get("swarm_data")
			if not bool(swarm_data.is_alive(target_idx)):
				return false
			var u_pos: Vector3 = swarm_sim.get_unit_position_3d(target_idx)
			return global_position.distance_to(u_pos) <= attack_range
	return false


func _acquire_best_target() -> Variant:
	if not is_inside_tree():
		return null

	var best_target: Variant = null
	var best_score: float = -INF
	var my_pos: Vector3 = global_position

	# 1. Evaluate SceneTree Enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for node: Node in enemies:
		if node is Node3D and is_instance_valid(node):
			var node_3d: Node3D = node as Node3D
			var hp: float = float(node_3d.get("current_health")) if "current_health" in node_3d else 1.0
			if hp <= 0.0:
				continue
			var dist: float = my_pos.distance_to(node_3d.global_position)
			if dist <= attack_range:
				var score: float = _calculate_threat_score(node_3d, dist)
				if score > best_score:
					best_score = score
					best_target = node_3d

	# 2. Evaluate Swarm Simulation Units
	var swarm_sim: Variant = _get_swarm_simulation()
	if swarm_sim and swarm_sim.get("spatial_hash") and swarm_sim.get("swarm_data"):
		var spatial_hash: Variant = swarm_sim.get("spatial_hash")
		var swarm_data: Variant = swarm_sim.get("swarm_data")
		var center_2d: Vector2 = Vector2(my_pos.x, my_pos.z)
		var candidates: PackedInt32Array = spatial_hash.query_radius(center_2d, attack_range, swarm_data)
		for idx: int in candidates:
			if bool(swarm_data.is_alive(idx)):
				var u_pos: Vector3 = swarm_sim.get_unit_position_3d(idx)
				var dist: float = my_pos.distance_to(u_pos)
				if dist <= attack_range:
					var arch_id: int = int(swarm_data.archetype_ids[idx])
					var score: float = _calculate_swarm_threat_score(arch_id, dist)
					if score > best_score:
						best_score = score
						best_target = idx

	return best_target


func _calculate_threat_score(node: Node3D, dist: float) -> float:
	var score: float = 0.0
	var name_lower: String = node.name.to_lower()

	if name_lower.contains("baneling") or node.is_in_group("banelings"):
		score += 1000.0 # Critical Kamikaze priority
	elif name_lower.contains("boss") or node.is_in_group("bosses"):
		score += 500.0  # Apex Boss priority
	elif name_lower.contains("hydra") or node.is_in_group("hydralisks"):
		score += 300.0  # Ranged Artillery priority
	elif name_lower.contains("roach") or node.is_in_group("roaches"):
		score += 200.0  # Armored Vanguard
	else:
		score += 100.0  # Zerglings / generic enemies

	# Distance tie-breaker (closer targets within same category score higher)
	score -= (dist / maxf(1.0, attack_range)) * 20.0
	return score


func _calculate_swarm_threat_score(arch_id: int, dist: float) -> float:
	var score: float = 0.0
	match arch_id:
		2: # Baneling
			score += 1000.0
		3: # Hydralisk
			score += 300.0
		1: # Roach
			score += 200.0
		_: # Zergling (0)
			score += 100.0
	score -= (dist / maxf(1.0, attack_range)) * 20.0
	return score


func _get_target_position(target: Variant) -> Vector3:
	if target is Node3D and is_instance_valid(target as Node3D):
		return (target as Node3D).global_position
	elif target is int:
		var swarm_sim: Variant = _get_swarm_simulation()
		if swarm_sim:
			return swarm_sim.get_unit_position_3d(target as int)
	return global_position + Vector3.FORWARD


func _track_yaw(target_pos: Vector3, delta: float) -> void:
	if not is_instance_valid(turret_head):
		return
	var dir: Vector3 = target_pos - turret_head.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		var target_yaw: float = atan2(-dir.x, -dir.z)
		var local_yaw: float = target_yaw - global_rotation.y
		turret_head.rotation.y = lerp_angle(turret_head.rotation.y, local_yaw, delta * tracking_speed)


func _idle_scan(delta: float) -> void:
	if is_instance_valid(turret_head) and not _is_headless:
		var sweep: float = sin(Time.get_ticks_msec() * 0.0015) * 0.35
		turret_head.rotation.y = lerp_angle(turret_head.rotation.y, sweep, delta * 2.0)


func _fire_at(target: Variant, target_pos: Vector3) -> void:
	_shot_count += 1

	# Determine target armor for combat calculation
	var armor: float = 0.0
	if target is Node3D and "flat_armor" in target:
		armor = float((target as Node3D).get("flat_armor"))
	elif target is int:
		var swarm_sim: Variant = _get_swarm_simulation()
		if swarm_sim and swarm_sim.get("swarm_data"):
			var swarm_data: Variant = swarm_sim.get("swarm_data")
			armor = float(swarm_data.armor_levels[target as int])

	# Calculate damage via SFECombatEngine
	var SFECombatEngineScript: GDScript = load("res://core/combat/sfe_combat_engine.gd") as GDScript
	var final_damage: float = attack_damage
	if SFECombatEngineScript:
		var res: Object = SFECombatEngineScript.calculate_damage(
			attack_damage,
			SFECombatEngineScript.DamageType.PHYSICAL,
			armor
		)
		if res != null and "damage_dealt" in res:
			final_damage = float(res.get("damage_dealt"))

	# Apply damage to target with Allied provenance (Crossfire Rule compliance)
	if target is Node3D and is_instance_valid(target as Node3D):
		var target_node: Node3D = target as Node3D
		target_node.set_meta("killer", self)
		target_node.set_meta("killer_faction", 0) # EconomyTypes.Faction.ALLIED
		if target_node.has_method("take_damage_context"):
			target_node.take_damage_context(attack_damage, 0, false, 0)
		elif target_node.has_method("take_damage"):
			target_node.take_damage(final_damage)
	elif target is int:
		var swarm_sim: Variant = _get_swarm_simulation()
		if swarm_sim:
			var killed: bool = bool(swarm_sim.apply_damage_to_unit(target as int, final_damage))
			if killed:
				_award_swarm_bounty(target as int, target_pos)

	# Visual VFX & Animation (guarded for headless runner)
	if not _is_headless:
		var vfx_pool: Node3D = _get_combat_vfx_pool()
		if vfx_pool and vfx_pool.has_method("spawn_tracer"):
			var barrel_marker: Marker3D = muzzle_left if (_shot_count % 2 == 1) else muzzle_right
			var origin_pos: Vector3 = barrel_marker.global_position if is_instance_valid(barrel_marker) else global_position + Vector3(0, 0.8, 0)
			vfx_pool.spawn_tracer(origin_pos, target_pos + Vector3(0, 0.4, 0))

		if anim_player != null:
			if anim_player.has_animation("shoot"):
				anim_player.play("shoot")
			elif anim_player.has_animation("attack"):
				anim_player.play("attack")

		var sfx: Node = _get_sfx_manager()
		if sfx and sfx.has_method("play_sfx_3d"):
			sfx.play_sfx_3d(&"turret_fire", global_position)

	turret_fired.emit(target, final_damage)


func _award_swarm_bounty(_unit_idx: int, death_pos: Vector3) -> void:
	if not _is_headless:
		var vfx_pool: Node3D = _get_combat_vfx_pool()
		if vfx_pool and vfx_pool.has_method("spawn_acid_burst"):
			vfx_pool.spawn_acid_burst(death_pos)

	var econ: Object = _get_economy_manager()
	if econ != null:
		var KillContextScript: GDScript = load("res://core/economy/kill_context.gd") as GDScript
		if KillContextScript:
			var ctx: Object = KillContextScript.new(null, self, 0, 10, 0)
			if econ.has_method("process_kill"):
				econ.process_kill(ctx)
			else:
				econ.add_minerals(10, "Swarm kill")
		else:
			econ.add_minerals(10, "Swarm kill")


func take_damage(amount: float) -> void:
	var mitigated: float = maxf(1.0, amount - flat_armor)
	current_health = maxf(0.0, current_health - mitigated)

	if health_bar != null and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)

	var sb: Node = _get_signal_bus()
	if sb and sb.has_signal("structure_damaged"):
		sb.structure_damaged.emit(self, current_health, max_health)

	turret_damaged.emit(current_health, max_health)

	if current_health <= 0.0:
		destroy()


func take_damage_context(amount: float, _damage_type: int = 0, _is_aoe: bool = false, _armor_level: int = 0) -> void:
	take_damage(amount)


func destroy() -> void:
	var sb: Node = _get_signal_bus()
	if sb and sb.has_signal("structure_destroyed"):
		sb.structure_destroyed.emit(self)

	turret_destroyed.emit(self)
	_unregister_flow_field_obstacle()

	if anim_player != null and anim_player.has_animation("death") and not _is_headless:
		set_physics_process(false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		anim_player.play("death")
		anim_player.animation_finished.connect(func(_a: StringName) -> void: queue_free(), CONNECT_ONE_SHOT)
	else:
		queue_free()


func apply_armory_upgrades(p_ballistics_tier: int, p_armor_tier: int) -> void:
	attack_damage = BASE_DAMAGE * (1.0 + 0.15 * p_ballistics_tier)
	attack_range = BASE_ATTACK_RANGE + (0.6 * p_ballistics_tier)
	attack_interval = maxf(0.05, BASE_ATTACK_INTERVAL / (1.0 + 0.08 * p_ballistics_tier))
	flat_armor = BASE_FLAT_ARMOR + (2.0 * p_armor_tier)


func _register_flow_field_obstacle() -> void:
	var flow_field: Variant = _get_flow_field()
	if flow_field != null and flow_field.has_method("register_obstacle"):
		var pos: Vector3 = global_position
		var r: float = FLOW_FIELD_RADIUS
		var world_min: Vector2 = Vector2(pos.x - r, pos.z - r)
		var world_max: Vector2 = Vector2(pos.x + r, pos.z + r)
		flow_field.register_obstacle(self, world_min, world_max, true, FLOW_FIELD_COST)
		_is_flow_field_registered = true


func _unregister_flow_field_obstacle() -> void:
	if _is_flow_field_registered:
		var flow_field: Variant = _get_flow_field()
		if flow_field != null and flow_field.has_method("unregister_obstacle"):
			flow_field.unregister_obstacle(self)
		_is_flow_field_registered = false


func _get_flow_field() -> Variant:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var swarm_sim: Node = tree.current_scene.get_node_or_null("SwarmSimulation")
		if swarm_sim and "flow_field" in swarm_sim:
			return swarm_sim.get("flow_field")
	return null


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.root and tree.root.has_node("SignalBus"):
			return tree.root.get_node("SignalBus")
	return null


func _get_swarm_simulation() -> Variant:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene.get_node_or_null("SwarmSimulation")
	return null


func _get_combat_vfx_pool() -> Node3D:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		return tree.current_scene.get_node_or_null("CombatVFXPool") as Node3D
	return null


func _get_economy_manager() -> Object:
	var SFEEconomyManagerScript: GDScript = load("res://core/economy/sfe_economy_manager.gd") as GDScript
	if SFEEconomyManagerScript and SFEEconomyManagerScript.instance:
		return SFEEconomyManagerScript.instance as Object
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			return tree.current_scene.get_node_or_null("EconomyManager") as Object
	return null


func _get_sfx_manager() -> Node:
	if Engine.has_singleton("SFXManager"):
		return Engine.get_singleton("SFXManager")
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.root and tree.root.has_node("SFXManager"):
			return tree.root.get_node("SFXManager")
	return null
