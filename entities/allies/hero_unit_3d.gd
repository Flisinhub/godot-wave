class_name HeroUnit3D
extends CharacterBody3D

## HeroUnit3D - Playable Hero Entity for SFE5.
## Extends CharacterBody3D directly per Requirement R4, tagged HEROIC in group "heroes".
## Bound to HeroData, using SFECombatEngine for damage calculations and SFEBuffEngine for buffs.

const CombatTypes = preload("res://core/combat/combat_types.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SFEBuffEngine = preload("res://core/combat/sfe_buff_engine.gd")
const CombatResult = preload("res://core/combat/combat_result.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")
const HeroAbilityVFX = preload("res://core/vfx/hero_ability_vfx.gd")
const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const AbilityComponent = preload("res://core/components/ability_component.gd")
const ExperienceComponent = preload("res://core/components/experience_component.gd")
const EliteComponent = preload("res://core/components/elite_component.gd")

signal skill_cast(skill: HeroSkillData, target: Variant)
signal hero_leveled_up(new_level: int)
signal hero_died_event(hero: Node, revive_time: float, mineral_penalty_pct: float)
signal hero_respawned(hero: Node)
signal revive_countdown_updated(remaining: float, total: float)

var is_dead: bool = false
var revive_timer: float = 0.0
var total_revive_time: float = 0.0
var spawn_position: Vector3 = Vector3(-22.0, 0.0, 20.0)
var current_difficulty_data: Resource = null
var swarm_simulation: Node = null

@export var hero_data: HeroData

# Node References (if present in visual scene)
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var selection_ring: MeshInstance3D = get_node_or_null("VisualRoot/SelectionRing")
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var health_bar: Node = get_node_or_null("HealthBar3D")
@onready var muzzle_flash: MeshInstance3D = get_node_or_null("VisualRoot/RifleMesh/MuzzleFlash")
@onready var anim_player: AnimationPlayer = get_node_or_null("VisualRoot/AnimationPlayer")
@onready var body_mesh: MeshInstance3D = get_node_or_null("VisualRoot/BodyMesh")
@onready var rifle_mesh: MeshInstance3D = get_node_or_null("VisualRoot/RifleMesh")


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null

# Combat & Utility Properties
var current_health: float = 550.0
var max_health: float = 550.0
var move_speed: float = 5.2
var attack_range: float = 8.5
var attack_damage: float = 28.0
var attack_cooldown: float = 0.8
var flat_armor: float = 1.0
var hp_regen: float = 1.0

var is_selected: bool = false
var focus_target: Node3D = null
var _attack_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Subsystems
var buff_engine: SFEBuffEngine = null
var skill_cooldowns: Dictionary = {} # skill_id -> remaining_seconds
var stats_component: StatsComponent = null
var buff_component: BuffComponent = null
var ability_component: AbilityComponent = null
var experience_component: ExperienceComponent = null
var elite_component: EliteComponent = null

# Target classification bitmask tagged HEROIC
var target_tags: int = CombatTypes.TargetTag.HEROIC | CombatTypes.TargetTag.BIOLOGICAL | CombatTypes.TargetTag.GROUND
var is_heroic: bool = true
var concussive_slow: bool = false
var healing_power: float = 1.0

func _init() -> void:
	add_to_group("allies")
	add_to_group("heroes")
	buff_engine = SFEBuffEngine.new()
	if hero_data == null:
		var selector = load("res://core/heroes/hero_selector.gd")
		if selector and selector.has_method("select_hero_manual"):
			hero_data = selector.select_hero_manual(&"marine")
		if hero_data == null:
			hero_data = HeroData.new()
	_bind_hero_data()

func _ready() -> void:
	add_to_group("allies")
	add_to_group("heroes")
	if buff_engine == null:
		buff_engine = SFEBuffEngine.new()

	if hero_data == null:
		var selector = load("res://core/heroes/hero_selector.gd")
		if selector and selector.has_method("select_hero_manual"):
			hero_data = selector.select_hero_manual(&"marine")
		if hero_data == null:
			hero_data = HeroData.new()

	_bind_hero_data()

	if selection_ring:
		selection_ring.visible = false
	if muzzle_flash:
		muzzle_flash.visible = false
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

	if nav_agent:
		nav_agent.path_desired_distance = 0.6
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance = 4.0
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.45
		nav_agent.max_speed = move_speed
		nav_agent.velocity_computed.connect(_on_navigation_agent_3d_velocity_computed)

	_ensure_animation_player()
	if is_instance_valid(anim_player) and anim_player.has_animation("idle"):
		anim_player.play("idle")

	var ArmoryMgrScript: GDScript = load("res://core/upgrades/armory_upgrade_manager.gd") as GDScript
	if ArmoryMgrScript and ArmoryMgrScript.instance != null:
		apply_armory_upgrades(ArmoryMgrScript.instance)
		if not ArmoryMgrScript.instance.upgrade_purchased.is_connected(_on_armory_upgrade_purchased):
			ArmoryMgrScript.instance.upgrade_purchased.connect(_on_armory_upgrade_purchased)


func _ensure_animation_player() -> void:
	if is_instance_valid(anim_player) and not anim_player.get_animation_list().is_empty():
		return
	var glb_path := "res://assets/models/raynor.glb"
	if FileAccess.file_exists(glb_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(glb_path, state) == OK:
			var scene := doc.generate_scene(state)
			if scene:
				var glb_anim := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
				if glb_anim:
					if not is_instance_valid(anim_player):
						anim_player = AnimationPlayer.new()
						anim_player.name = "AnimationPlayer"
						if is_instance_valid(visual_root):
							visual_root.add_child(anim_player)
						else:
							add_child(anim_player)
					if is_instance_valid(anim_player):
						for lib_name in glb_anim.get_animation_library_list():
							var lib := glb_anim.get_animation_library(lib_name)
							if not anim_player.has_animation_library(lib_name):
								anim_player.add_animation_library(lib_name, lib)
				scene.queue_free()


func _ensure_components() -> void:
	if not stats_component:
		stats_component = get_node_or_null("StatsComponent") as StatsComponent
		if not stats_component:
			stats_component = StatsComponent.new()
			stats_component.name = "StatsComponent"
			add_child(stats_component)
		if not stats_component.stats_changed.is_connected(_sync_from_stats_component):
			stats_component.stats_changed.connect(_sync_from_stats_component)
	
	if not buff_component:
		buff_component = get_node_or_null("BuffComponent") as BuffComponent
		if not buff_component:
			buff_component = BuffComponent.new()
			buff_component.name = "BuffComponent"
			add_child(buff_component)
	
	if not ability_component:
		ability_component = get_node_or_null("AbilityComponent") as AbilityComponent
		if not ability_component:
			ability_component = AbilityComponent.new()
			ability_component.name = "AbilityComponent"
			ability_component.stats_component = stats_component
			add_child(ability_component)
	
	if not experience_component:
		experience_component = get_node_or_null("ExperienceComponent") as ExperienceComponent
		if not experience_component:
			experience_component = ExperienceComponent.new()
			experience_component.name = "ExperienceComponent"
			experience_component.stats_component = stats_component
			add_child(experience_component)
			if not experience_component.level_up.is_connected(_on_experience_level_up):
				experience_component.level_up.connect(_on_experience_level_up)

	if not elite_component:
		elite_component = get_node_or_null("EliteComponent") as EliteComponent
		if not elite_component:
			elite_component = EliteComponent.new()
			elite_component.name = "EliteComponent"
			add_child(elite_component)


func promote_to_elite() -> void:
	_ensure_components()
	if elite_component:
		elite_component.promote_to_elite()


func _sync_from_stats_component() -> void:
	if not stats_component:
		return
	var old_max_hp: float = max_health
	max_health = stats_component.get_effective_max_hp()
	var hp_delta: float = max_health - old_max_hp
	if hp_delta > 0.0:
		current_health += hp_delta
	current_health = clampf(current_health, 1.0, max_health)

	attack_damage = stats_component.get_effective_damage()
	attack_cooldown = stats_component.get_effective_attack_period()
	flat_armor = stats_component.get_effective_armor()
	move_speed = stats_component.base_move_speed

	if hero_data:
		hero_data.strength = stats_component.strength
		hero_data.dexterity = stats_component.dexterity
		hero_data.intelligence = stats_component.intelligence
		hero_data.endurance = stats_component.endurance
		hero_data.max_hp = max_health
		hero_data.current_hp = current_health
		hero_data.weapon_damage = attack_damage
		hero_data.attack_cooldown = attack_cooldown
		hero_data.effective_armor = flat_armor
		hero_data.max_energy = stats_component.get_effective_max_energy()
		hero_data.energy_regen = stats_component.get_effective_energy_regen()

	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)


func _on_stats_component_changed() -> void:
	_sync_from_stats_component()


func _on_experience_level_up(new_lvl: int) -> void:
	hero_leveled_up.emit(new_lvl)
	if hero_data:
		hero_data.xp_level = new_lvl


func _bind_hero_data() -> void:
	if hero_data == null:
		return

	_ensure_components()

	if not hero_data.derived_stats_updated.is_connected(_on_derived_stats_updated):
		hero_data.derived_stats_updated.connect(_on_derived_stats_updated)
	if not hero_data.level_up.is_connected(_on_hero_level_up):
		hero_data.level_up.connect(_on_hero_level_up)

	# Synchronize stats_component
	if stats_component:
		stats_component.base_max_hp = hero_data.base_hp
		stats_component.base_damage = hero_data.base_damage
		stats_component.base_attack_period = hero_data.base_cooldown
		stats_component.base_armor = hero_data.flat_armor
		stats_component.base_max_energy = hero_data.base_energy
		stats_component.base_energy_regen = hero_data.base_energy_regen
		stats_component.base_move_speed = hero_data.move_speed
		stats_component.strength = hero_data.strength
		stats_component.dexterity = hero_data.dexterity
		stats_component.intelligence = hero_data.intelligence
		stats_component.endurance = hero_data.endurance
		stats_component.recalculate()

	# Synchronize ability_component skills
	if ability_component and not hero_data.skills.is_empty():
		var slots := ["Q", "W", "E", "R"]
		for i in range(mini(slots.size(), hero_data.skills.size())):
			if hero_data.skills[i]:
				ability_component.bind_skill(slots[i], hero_data.skills[i])

	hero_data.recalculate_derived_stats(true)
	_apply_hero_stats_to_unit()

func _apply_hero_stats_to_unit() -> void:
	if hero_data == null:
		return
	max_health = hero_data.max_hp
	current_health = hero_data.current_hp
	move_speed = hero_data.move_speed
	attack_range = hero_data.attack_range
	attack_damage = hero_data.weapon_damage
	attack_cooldown = hero_data.attack_cooldown
	flat_armor = hero_data.effective_armor if "effective_armor" in hero_data else hero_data.flat_armor
	hp_regen = hero_data.hp_regen

	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead:
		revive_timer = maxf(0.0, revive_timer - delta)
		revive_countdown_updated.emit(revive_timer, total_revive_time)
		if revive_timer <= 0.0:
			respawn(spawn_position)
		return

	# 1. Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = maxf(0.0, _attack_timer - delta)

	# 2. Buff engine tick
	if buff_engine:
		buff_engine.tick(delta)

	# 2b. BuffComponent tick for conditional buffs (Momentum, Bulwark, Optical Lens, Static Charge, Demiurge)
	if buff_component:
		var speed_2d: float = Vector2(velocity.x, velocity.z).length()
		var energy_ratio: float = 1.0
		if hero_data:
			energy_ratio = hero_data.current_energy / maxf(1.0, hero_data.max_energy)
		buff_component.update_conditions(delta, speed_2d, energy_ratio)

	# 3. HP and Energy regeneration from derived RPG attributes & armory upgrades
	if hero_data:
		var effective_regen: float = hp_regen if hp_regen > 0.0 else hero_data.hp_regen
		var hp_regen_rate: float = effective_regen * (buff_engine.get_total_stat_multiplier("hp_regen") if buff_engine else 1.0)
		if current_health < hero_data.max_hp:
			current_health = minf(hero_data.max_hp, current_health + (hp_regen_rate * delta))
			hero_data.current_hp = current_health
			if health_bar and health_bar.has_method("update_health"):
				health_bar.update_health(current_health, max_health)

		var energy_regen_rate: float = hero_data.energy_regen * (buff_engine.get_total_stat_multiplier("energy_regen") if buff_engine else 1.0)
		if hero_data.current_energy < hero_data.max_energy:
			hero_data.current_energy = minf(hero_data.max_energy, hero_data.current_energy + (energy_regen_rate * delta))

	# 4. Update skill cooldown sweeps
	if not skill_cooldowns.is_empty():
		for skill_id in skill_cooldowns.keys():
			var cd: float = skill_cooldowns[skill_id]
			if cd > 0.0:
				skill_cooldowns[skill_id] = maxf(0.0, cd - delta)

	# 5. Handle Focus Target
	if is_instance_valid(focus_target):
		var dist: float = global_position.distance_to(focus_target.global_position)
		if dist > attack_range:
			_navigate_towards(focus_target.global_position, delta)
			_update_animations()
			return
		else:
			_stop_movement(delta)
			_look_at_target(focus_target.global_position, delta)
			if _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				_fire_at(focus_target)
			_update_animations()
			return
	else:
		focus_target = null

	# 6. Handle NavigationAgent movement
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos: Vector3 = nav_agent.get_next_path_position()
		var move_dir: Vector3 = (next_pos - global_position)
		move_dir.y = 0.0

		if move_dir.length_squared() > 0.001:
			move_dir = move_dir.normalized()
			var intended_vel: Vector3 = move_dir * move_speed
			if nav_agent.avoidance_enabled:
				nav_agent.set_velocity(intended_vel)
			else:
				_apply_movement_velocity(intended_vel, delta)
		else:
			_stop_movement(delta)
		_update_animations()
		return

	# 7. Stationary Behavior: Auto-Attack nearby enemies within attack_range (Hostile Nodes & Swarm Units)
	_stop_movement(delta)
	var enemy: Node3D = _find_nearest_enemy_in_range()
	if enemy:
		_look_at_target(enemy.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_fire_at(enemy)
	else:
		var swarm_target: Dictionary = _find_nearest_swarm_unit(attack_range)
		if not swarm_target.is_empty():
			var spos: Vector3 = swarm_target["position"]
			_look_at_target(spos, delta)
			if _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				_fire_at_swarm(int(swarm_target["index"]), spos)
	_update_animations()


func _update_animations() -> void:
	if not is_instance_valid(anim_player):
		return
	if anim_player.current_animation == "death":
		return
	
	var is_moving: bool = Vector2(velocity.x, velocity.z).length_squared() > 0.04
	if is_moving:
		if anim_player.current_animation != "run":
			if anim_player.has_animation("run"):
				anim_player.play("run")
			elif anim_player.has_animation("walk"):
				anim_player.play("walk")
	else:
		if (anim_player.current_animation == "shoot" or anim_player.current_animation == "attack") and anim_player.is_playing():
			return
		if anim_player.current_animation != "idle":
			if anim_player.has_animation("idle"):
				anim_player.play("idle")

func _navigate_towards(target_pos: Vector3, _delta: float) -> void:
	if not nav_agent:
		return
	target_pos.y = 0.0
	nav_agent.target_position = target_pos

	if not nav_agent.is_navigation_finished():
		var next_pos: Vector3 = nav_agent.get_next_path_position()
		var move_dir: Vector3 = (next_pos - global_position)
		move_dir.y = 0.0
		if move_dir.length_squared() > 0.001:
			move_dir = move_dir.normalized()
			nav_agent.set_velocity(move_dir * move_speed)
		else:
			nav_agent.set_velocity(Vector3.ZERO)

func _stop_movement(delta: float) -> void:
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 8.0)
	move_and_slide()

func _look_at_target(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		var target_angle_y: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 14.0)

func _apply_movement_velocity(vel: Vector3, delta: float) -> void:
	if vel.length_squared() > 0.01:
		var target_angle_y: float = atan2(-vel.x, -vel.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 12.0)
	velocity.x = vel.x
	velocity.z = vel.z
	move_and_slide()

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_apply_movement_velocity(safe_velocity, get_physics_process_delta_time())

func _find_nearest_enemy_in_range() -> Node3D:
	if not is_inside_tree():
		return null
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var min_dist: float = attack_range

	for node in enemies:
		if node is Node3D and is_instance_valid(node):
			var dist: float = global_position.distance_to(node.global_position)
			if dist <= min_dist:
				min_dist = dist
				nearest = node as Node3D

	return nearest


func _get_swarm_simulation() -> Node:
	if swarm_simulation and is_instance_valid(swarm_simulation):
		return swarm_simulation
	if is_inside_tree():
		var node := get_tree().root.find_child("SwarmSimulation", true, false)
		if node:
			swarm_simulation = node
			return swarm_simulation
	return null


func _notify_swarm_kill(unit_idx: int, hit_pos: Vector3) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree and tree.root:
		var ml: Node = tree.root.find_child("MainLevel", true, false)
		if ml and ml.has_method("_on_swarm_unit_killed"):
			ml._on_swarm_unit_killed(unit_idx, self, hit_pos, 5)


func _find_nearest_swarm_unit(max_dist: float) -> Dictionary:
	var sim = _get_swarm_simulation()
	if sim and "spatial_hash" in sim and sim.spatial_hash and "swarm_data" in sim and sim.swarm_data:
		var center_2d := Vector2(global_position.x, global_position.z)
		var hits: PackedInt32Array = sim.spatial_hash.query_radius(center_2d, max_dist, sim.swarm_data)
		var nearest_idx: int = -1
		var nearest_dist: float = max_dist
		var nearest_pos: Vector3 = Vector3.ZERO
		for idx in hits:
			var u_pos := Vector3(sim.swarm_data.pos_x[idx], 0.35, sim.swarm_data.pos_z[idx])
			var d := global_position.distance_to(u_pos)
			if d <= nearest_dist:
				nearest_dist = d
				nearest_idx = idx
				nearest_pos = u_pos
		if nearest_idx >= 0:
			return {"index": nearest_idx, "position": nearest_pos, "distance": nearest_dist}
	return {}


func _fire_at_swarm(target_idx: int, target_pos: Vector3) -> void:
	var sim = _get_swarm_simulation()
	if sim == null:
		return
	var base_dmg: float = stats_component.get_effective_damage() if stats_component else (hero_data.weapon_damage if hero_data else attack_damage)
	var buff_mult: float = buff_engine.get_total_stat_multiplier("attack_damage") if buff_engine else 1.0
	var tier_buff_mult: float = buff_component.get_damage_multiplier(false) if buff_component else 1.0
	var final_damage: float = base_dmg * buff_mult * tier_buff_mult

	if is_inside_tree():
		var vfx_pool = get_tree().root.find_child("CombatVFXPool", true, false)
		if vfx_pool and vfx_pool.has_method("spawn_tracer"):
			vfx_pool.spawn_tracer(global_position + Vector3(0.0, 1.1, 0.0), target_pos)

	if is_instance_valid(anim_player):
		if anim_player.has_animation("shoot"):
			anim_player.play("shoot")
		elif anim_player.has_animation("attack"):
			anim_player.play("attack")

	if muzzle_flash:
		muzzle_flash.visible = true
		var tween: Tween = create_tween()
		if tween:
			tween.tween_interval(0.06)
			tween.tween_callback(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)

	var killed: bool = bool(sim.apply_damage_to_unit(target_idx, final_damage))
	if killed:
		_notify_swarm_kill(target_idx, target_pos)


## Routes damage calculation through SFECombatEngine with HEROIC tag and invulnerability checks.
func take_damage_context(
	raw_amount: float,
	damage_type: int = CombatTypes.DamageType.PHYSICAL,
	is_aoe: bool = false,
	armor_upgrade_level: int = 0
) -> CombatResult:
	if buff_component:
		buff_component.record_damage_taken()

	var is_invuln: bool = buff_engine.is_invulnerable() if buff_engine else false
	var hero_armor: float = flat_armor
	var hero_shield: float = hero_data.current_shield if hero_data else 0.0

	var result: CombatResult = SFECombatEngine.calculate_damage(
		raw_amount,
		damage_type,
		hero_armor,
		armor_upgrade_level,
		CombatTypes.StructureType.NONE,
		true, # is_heroic = true -> applies AoE spell damage reductions
		is_aoe,
		is_invuln,
		hero_shield,
		current_health,
		target_tags
	)

	# Apply flat mitigation from Neutron Armor (Task 4.10)
	var net_damage: float = result.damage_dealt
	if stats_component:
		var neutron_mitigation: float = stats_component.get_neutron_armor_mitigation()
		net_damage = maxf(1.0 if net_damage > 0.0 else 0.0, net_damage - neutron_mitigation)

	# Apply percentage mitigation from BuffComponent (Bulwark, etc.)
	if buff_component:
		var buff_mitigation_ratio: float = buff_component.get_mitigation_ratio()
		net_damage = maxf(0.0, net_damage * (1.0 - buff_mitigation_ratio))

	result.damage_dealt = net_damage

	if hero_data and result.absorbed > 0.0:
		hero_data.current_shield = maxf(0.0, hero_data.current_shield - result.absorbed)

	current_health = maxf(0.0, current_health - net_damage)
	if hero_data:
		hero_data.current_hp = current_health

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)

	var sb := _get_signal_bus()
	if sb:
		sb.emit_signal("unit_health_changed", self, current_health, max_health)

	if current_health <= 0.0:
		if buff_component and buff_component.attempt_cheat_death():
			current_health = max_health * 0.35
			if hero_data:
				hero_data.current_hp = current_health
			FloatingTextManager.spawn_text(self, get_world_pos() + Vector3(0, 2.5, 0), "¡DEMIURGE SALVADOR!", Color(0.2, 0.9, 1.0))
		else:
			die()

	return result

## Overrides take_damage to ensure full integration with SFECombatEngine.
func take_damage(amount: float) -> void:
	take_damage_context(amount, CombatTypes.DamageType.PHYSICAL, false, 0)

## Overrides auto-attack firing to use hero derived damage and buffs.
func _fire_at(target: Node3D) -> void:
	if not is_instance_valid(target):
		return

	# Tychus Minigun Passive: Each attack stacks minigun cadence buff up to 20 stacks
	if hero_data and (hero_data.archetype_id == &"tychus" or hero_data.archetype_id == &"marauder"):
		if buff_engine:
			buff_engine.apply_buff(&"tychus_passive", 4.0, 20)

	var base_dmg: float = stats_component.get_effective_damage() if stats_component else (hero_data.weapon_damage if hero_data else attack_damage)
	var buff_mult: float = buff_engine.get_total_stat_multiplier("attack_damage") if buff_engine else 1.0
	var tier_buff_mult: float = buff_component.get_damage_multiplier(target.is_in_group("heroes") or target.is_in_group("bosses")) if buff_component else 1.0
	var final_damage: float = base_dmg * buff_mult * tier_buff_mult

	if target.has_method("take_damage_context"):
		target.take_damage_context(final_damage, CombatTypes.DamageType.PHYSICAL, false, 0)
	elif target.has_method("take_damage"):
		target.take_damage(final_damage)

	if concussive_slow or (has_meta("concussive_slow") and bool(get_meta("concussive_slow"))):
		if target.has_method("apply_slow"):
			target.apply_slow(0.25, 2.0)
		elif "move_speed" in target:
			target.move_speed = maxf(0.5, target.move_speed * 0.75)

	if is_instance_valid(anim_player):
		if anim_player.has_animation("shoot"):
			anim_player.play("shoot")
		elif anim_player.has_animation("attack"):
			anim_player.play("attack")

	if muzzle_flash:
		muzzle_flash.visible = true
		var tween: Tween = create_tween()
		if tween:
			tween.tween_interval(0.06)
			tween.tween_callback(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)


func die() -> void:
	if is_dead:
		return
	is_dead = true

	var sb := _get_signal_bus()
	if sb:
		sb.emit_signal("unit_died", self)

	# Determine difficulty
	var diff = current_difficulty_data
	if diff == null and ResourceLoader.exists("res://data/difficulties/normal.tres"):
		diff = load("res://data/difficulties/normal.tres")

	var is_permadeath: bool = diff.get("permadeath") if (diff and "permadeath" in diff) else false
	if is_permadeath:
		hero_died_event.emit(self, 0.0, 1.0)
		if sb and sb.has_signal("base_destroyed"):
			sb.emit_signal("base_destroyed")
		if is_instance_valid(anim_player) and anim_player.has_animation("death") and DisplayServer.get_name() != "headless":
			set_physics_process(false)
			anim_player.play("death")
		else:
			queue_free()
		return

	var hero_lvl: int = 1
	if experience_component:
		hero_lvl = experience_component.current_level
	elif hero_data:
		hero_lvl = hero_data.xp_level

	total_revive_time = diff.calculate_revive_time(hero_lvl) if (diff and diff.has_method("calculate_revive_time")) else (20.0 + float(hero_lvl) * 0.4)
	revive_timer = total_revive_time

	var pen_pct: float = diff.get("mineral_penalty_on_death") if (diff and "mineral_penalty_on_death" in diff) else 0.25

	# Deduct mineral penalty from economy manager
	var econ = get_tree().root.find_child("EconomyManager", true, false) if is_inside_tree() else null
	if econ and "current_minerals" in econ:
		var penalty := int(float(econ.current_minerals) * pen_pct)
		if penalty > 0 and econ.has_method("spend_minerals"):
			econ.spend_minerals(penalty)

	# Strip buffs according to difficulty
	var loses_buffs: bool = diff.get("loses_buffs_on_death") if (diff and "loses_buffs_on_death" in diff) else true
	var buff_retention: float = diff.get("buff_cost_retention") if (diff and "buff_cost_retention" in diff) else 0.25
	if loses_buffs and buff_component:
		buff_component.strip_buffs_on_death(buff_retention)

	hero_died_event.emit(self, total_revive_time, pen_pct)

	# Visual hiding & collision disable
	velocity = Vector3.ZERO
	if nav_agent:
		nav_agent.target_position = get_world_pos()

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", true)
	if selection_ring:
		selection_ring.visible = false
	if health_bar:
		health_bar.visible = false
	if visual_root:
		visual_root.visible = false


func respawn(pos: Vector3 = Vector3.ZERO) -> void:
	is_dead = false
	revive_timer = 0.0
	var target_pos: Vector3 = pos if pos != Vector3.ZERO else spawn_position
	set_world_pos(target_pos)
	velocity = Vector3.ZERO

	current_health = max_health
	if hero_data:
		hero_data.current_hp = max_health
		hero_data.current_energy = hero_data.max_energy

	if visual_root:
		visual_root.visible = true
	if health_bar:
		health_bar.visible = true
		if health_bar.has_method("setup"):
			health_bar.setup(current_health, max_health)

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.set_deferred("disabled", false)

	# Brief invulnerability shield (Task 7.5: 3.5s)
	if buff_engine:
		buff_engine.apply_buff({"buff_id": &"invulnerability", "default_duration": 3.5, "is_invulnerable": true}, 3.5)

	hero_respawned.emit(self)

	if is_inside_tree():
		FloatingTextManager.spawn_text(
			self,
			get_world_pos() + Vector3(0, 2.5, 0),
			"¡HÉROE REVIVIDO!",
			Color(0.2, 0.95, 0.4)
		)


func get_world_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func set_world_pos(p: Vector3) -> void:
	if is_inside_tree():
		global_position = p
	else:
		position = p


func get_facing_direction() -> Vector3:
	var b: Basis = global_transform.basis if is_inside_tree() else transform.basis
	return -b.z


## Activates a skill by slot index (0 = Q, 1 = W, 2 = E, 3 = R).
func activate_skill(slot_index: int, target: Variant = null) -> bool:
	if hero_data == null or slot_index < 0 or slot_index >= hero_data.skills.size():
		return false
	var skill: HeroSkillData = hero_data.skills[slot_index] as HeroSkillData
	if skill == null:
		return false
	return cast_skill(skill, target)


## Casts an active ability using energy from HeroData and tracking cooldown.
func cast_skill(skill: HeroSkillData, target: Variant = null) -> bool:
	if skill == null or hero_data == null:
		return false

	var remaining_cd: float = skill_cooldowns.get(skill.skill_id, 0.0)
	if not skill.can_cast(hero_data.current_energy, remaining_cd > 0.0):
		return false

	# Archetype-specific casting preconditions & mechanics
	match skill.skill_id:
		&"stimpack":
			# Stimpack consumes 10 HP (cannot kill, min 1.0 HP)
			if current_health <= 10.0:
				return false
			current_health = maxf(1.0, current_health - 10.0)
			hero_data.current_hp = current_health
			if health_bar and health_bar.has_method("update_health"):
				health_bar.update_health(current_health, max_health)
			if buff_engine != null:
				buff_engine.apply_buff(&"stimpack", skill.buff_duration if skill.buff_duration > 0.0 else 8.0)
			_spawn_stimpack_vfx()

		&"penetrating_round":
			var cur_pos: Vector3 = get_world_pos()
			var dir: Vector3 = get_facing_direction()
			if target is Vector3:
				var delta_v: Vector3 = (target as Vector3) - cur_pos
				delta_v.y = 0.0
				if delta_v.length_squared() > 0.001:
					dir = delta_v.normalized()
			var pen_range: float = skill.cast_range if skill.cast_range > 0.0 else 12.0
			var pen_width: float = skill.area_radius if skill.area_radius > 0.0 else 1.2
			var pen_end: Vector3 = cur_pos + (dir * pen_range)
			_apply_line_damage(cur_pos, pen_end, pen_width, skill.base_power, CombatTypes.DamageType.PHYSICAL)
			_spawn_penetrating_round_vfx(cur_pos, dir, pen_range)

		&"orbital_bombardment":
			var cur_pos: Vector3 = get_world_pos()
			var bomb_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 12.0))
			var bomb_radius: float = skill.area_radius if skill.area_radius > 0.0 else 8.0
			_apply_aoe_damage(bomb_center, bomb_radius, skill.base_power, CombatTypes.DamageType.SPELL)
			_spawn_orbital_bombardment_vfx(bomb_center, bomb_radius)

		&"overkill":
			if buff_engine != null:
				buff_engine.apply_buff(&"frenzy", skill.buff_duration if skill.buff_duration > 0.0 else 6.0)
				buff_engine.apply_buff(&"tychus_passive", skill.buff_duration if skill.buff_duration > 0.0 else 6.0, 20)
			_spawn_overkill_vfx()

		&"frag_grenade", &"shredder_grenade":
			var cur_pos: Vector3 = get_world_pos()
			var nade_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 6.0))
			var nade_radius: float = skill.area_radius if skill.area_radius > 0.0 else 4.5
			_apply_aoe_damage(nade_center, nade_radius, skill.base_power, skill.damage_type)
			_spawn_grenade_explosion_vfx(nade_center, nade_radius)

		&"snipe":
			var cur_pos: Vector3 = get_world_pos()
			var target_enemy: Node3D = null
			if target is Node3D and is_instance_valid(target):
				target_enemy = target as Node3D
			elif focus_target != null and is_instance_valid(focus_target):
				target_enemy = focus_target
			else:
				target_enemy = _find_nearest_enemy_in_range()

			var target_pos: Vector3 = target_enemy.global_position if (target_enemy and target_enemy.is_inside_tree()) else (cur_pos + get_facing_direction() * (skill.cast_range if skill.cast_range > 0.0 else 14.0))
			if target_enemy:
				_apply_single_target_damage(target_enemy, skill.base_power if skill.base_power > 0.0 else 250.0, CombatTypes.DamageType.SPELL)
			_spawn_snipe_vfx(cur_pos + Vector3(0, 1.2, 0), target_pos + Vector3(0, 0.8, 0))

		&"tactical_cloak":
			if buff_engine != null:
				buff_engine.apply_buff(&"cloak", skill.buff_duration if skill.buff_duration > 0.0 else 15.0)
			_spawn_cloak_vfx()

		&"blink":
			var cur_pos: Vector3 = get_world_pos()
			var dest: Vector3 = cur_pos + (get_facing_direction() * 8.0)
			if target is Vector3:
				var delta_v: Vector3 = (target as Vector3) - cur_pos
				delta_v.y = 0.0
				if delta_v.length() > 8.0:
					delta_v = delta_v.normalized() * 8.0
				dest = cur_pos + delta_v
			_spawn_blink_vfx(cur_pos, dest)
			set_world_pos(dest)
			if nav_agent:
				nav_agent.target_position = dest

		&"shadow_cleave":
			var cur_pos: Vector3 = get_world_pos()
			var cleave_radius: float = skill.area_radius if skill.area_radius > 0.0 else 3.8
			_apply_aoe_damage(cur_pos, cleave_radius, skill.base_power, CombatTypes.DamageType.PHYSICAL)
			_spawn_shadow_cleave_vfx(cur_pos, cleave_radius)

		&"psionic_storm":
			var cur_pos: Vector3 = get_world_pos()
			var storm_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 6.0))
			var storm_radius: float = skill.area_radius if skill.area_radius > 0.0 else 5.2
			_apply_aoe_damage(storm_center, storm_radius, skill.base_power, CombatTypes.DamageType.SPELL)
			_spawn_psionic_storm_vfx(storm_center, storm_radius)

		&"plasma_shield":
			hero_data.current_shield = minf(hero_data.max_shield if hero_data.max_shield > 0.0 else 300.0, hero_data.current_shield + 150.0)
			if buff_engine != null:
				buff_engine.apply_buff(&"invulnerability_shield", skill.buff_duration if skill.buff_duration > 0.0 else 3.5)
			_spawn_shield_bubble_vfx()

		&"heal_beam":
			var cur_pos: Vector3 = get_world_pos()
			var lowest_ally: Node3D = null
			var lowest_pct: float = 1.0
			var allies: Array = get_tree().get_nodes_in_group("allies") if is_inside_tree() else []
			for a in allies:
				if a is Node3D and is_instance_valid(a) and a != self:
					var hp_cur: float = a.current_health if "current_health" in a else 100.0
					var hp_max: float = a.max_health if "max_health" in a else 100.0
					if hp_max > 0.0 and hp_cur < hp_max:
						var pct: float = hp_cur / hp_max
						var a_pos: Vector3 = a.global_position if a.is_inside_tree() else a.position
						if pct < lowest_pct and cur_pos.distance_to(a_pos) <= 9.0:
							lowest_pct = pct
							lowest_ally = a
			if lowest_ally:
				if lowest_ally.has_method("heal"):
					lowest_ally.heal(skill.base_power)
				elif "current_health" in lowest_ally:
					lowest_ally.current_health = minf(lowest_ally.max_health, lowest_ally.current_health + skill.base_power)
					if "health_bar" in lowest_ally and lowest_ally.health_bar and lowest_ally.health_bar.has_method("update_health"):
						lowest_ally.health_bar.update_health(lowest_ally.current_health, lowest_ally.max_health)
				var a_pos: Vector3 = lowest_ally.global_position if lowest_ally.is_inside_tree() else lowest_ally.position
				_spawn_heal_beam_vfx(cur_pos + Vector3(0, 1.2, 0), a_pos + Vector3(0, 1.0, 0))
				FloatingTextManager.spawn_text(self, a_pos, "+%d HP" % int(skill.base_power), Color(0.2, 0.95, 0.4))
			else:
				# Self-heal fallback
				current_health = minf(max_health, current_health + skill.base_power)
				hero_data.current_hp = current_health
				if health_bar and health_bar.has_method("update_health"):
					health_bar.update_health(current_health, max_health)
				FloatingTextManager.spawn_text(self, cur_pos, "+%d HP" % int(skill.base_power), Color(0.2, 0.95, 0.4))

		&"defensive_matrix":
			hero_data.current_shield = minf(hero_data.max_shield if hero_data.max_shield > 0.0 else 200.0, hero_data.current_shield + 150.0)
			if buff_engine != null:
				buff_engine.apply_buff(&"armor_boost", skill.buff_duration if skill.buff_duration > 0.0 else 7.0)
			_spawn_defensive_matrix_vfx()
			_spawn_shield_bubble_vfx()

		&"celestial_singularity":
			var cur_pos: Vector3 = get_world_pos()
			var sing_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 8.0))
			var sing_radius: float = skill.area_radius if skill.area_radius > 0.0 else 6.0
			_apply_gravitational_pull(sing_center, sing_radius)
			_apply_aoe_damage(sing_center, sing_radius, skill.base_power, CombatTypes.DamageType.SPELL)
			_spawn_celestial_singularity_vfx(sing_center, sing_radius)

		&"dimensional_beam":
			var cur_pos: Vector3 = get_world_pos()
			var target_enemy: Node3D = null
			if target is Node3D and is_instance_valid(target):
				target_enemy = target as Node3D
			elif focus_target != null and is_instance_valid(focus_target):
				target_enemy = focus_target
			else:
				target_enemy = _find_nearest_enemy_in_range()

			var target_pos: Vector3 = target_enemy.global_position if (target_enemy and target_enemy.is_inside_tree()) else (cur_pos + get_facing_direction() * (skill.cast_range if skill.cast_range > 0.0 else 11.0))
			if target_enemy:
				_apply_single_target_damage(target_enemy, skill.base_power if skill.base_power > 0.0 else 220.0, CombatTypes.DamageType.SPELL)
			_spawn_dimensional_beam_vfx(cur_pos + Vector3(0, 1.2, 0), target_pos + Vector3(0, 0.8, 0))

		_:
			# Generic fallback execution
			if skill.base_power > 0.0:
				if target is Node3D and is_instance_valid(target):
					_apply_single_target_damage(target, skill.base_power, skill.damage_type)
				elif skill.area_radius > 0.0:
					var target_pos: Vector3 = target if target is Vector3 else get_world_pos()
					_apply_aoe_damage(target_pos, skill.area_radius, skill.base_power, skill.damage_type)

	# Deduct energy
	hero_data.current_energy -= skill.energy_cost

	# Set cooldown
	skill_cooldowns[skill.skill_id] = skill.cooldown

	# Apply buff if defined
	if skill.buff_id != &"" and buff_engine != null:
		var duration: float = skill.buff_duration if skill.buff_duration > 0.0 else 5.0
		buff_engine.apply_buff(skill.buff_id, duration)

	skill_cast.emit(skill, target)
	return true


func _apply_aoe_damage(center: Vector3, radius: float, damage: float, damage_type: int) -> void:
	if not is_inside_tree():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			var dist: float = center.distance_to(e.global_position)
			if dist <= radius:
				var flat_arm: float = e.get("flat_armor") if "flat_armor" in e else 0.0
				var is_heroic: bool = e.is_in_group("heroes") or (e.get("is_heroic") == true if "is_heroic" in e else false)
				var calc_result: CombatResult = SFECombatEngine.calculate_damage(
					damage,
					damage_type,
					flat_arm,
					0,
					SFECombatEngine.StructureType.NONE,
					is_heroic,
					true,
					false
				)
				if e.has_method("take_damage_context"):
					e.take_damage_context(calc_result.damage_dealt, damage_type, true, 0)
				elif e.has_method("take_damage"):
					e.take_damage(calc_result.damage_dealt)

	# Also apply AoE damage to mass Swarm units via spatial hash
	var sim = _get_swarm_simulation()
	if sim and "spatial_hash" in sim and sim.spatial_hash and "swarm_data" in sim and sim.swarm_data:
		var center_2d := Vector2(center.x, center.z)
		var hits: PackedInt32Array = sim.spatial_hash.query_radius(center_2d, radius, sim.swarm_data)
		for idx in hits:
			var hit_pos := Vector3(sim.swarm_data.pos_x[idx], 0.35, sim.swarm_data.pos_z[idx])
			var killed: bool = bool(sim.apply_damage_to_unit(idx, damage))
			if killed:
				_notify_swarm_kill(idx, hit_pos)


func _apply_line_damage(from_pos: Vector3, to_pos: Vector3, width: float, damage: float, damage_type: int) -> void:
	if not is_inside_tree():
		return
	var seg_dir: Vector3 = to_pos - from_pos
	var seg_len_sq: float = seg_dir.length_squared()
	if seg_len_sq < 0.001:
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			var e_pos: Vector3 = e.global_position
			var t: float = clampf((e_pos - from_pos).dot(seg_dir) / seg_len_sq, 0.0, 1.0)
			var proj: Vector3 = from_pos + seg_dir * t
			var dist: float = e_pos.distance_to(proj)
			if dist <= width:
				var flat_arm: float = e.get("flat_armor") if "flat_armor" in e else 0.0
				var calc_result: CombatResult = SFECombatEngine.calculate_damage(
					damage,
					damage_type,
					flat_arm,
					0,
					SFECombatEngine.StructureType.NONE,
					false,
					false,
					false
				)
				if e.has_method("take_damage_context"):
					e.take_damage_context(calc_result.damage_dealt, damage_type, false, 0)
				elif e.has_method("take_damage"):
					e.take_damage(calc_result.damage_dealt)

	# Also apply Line damage to mass Swarm units
	var sim = _get_swarm_simulation()
	if sim and "spatial_hash" in sim and sim.spatial_hash and "swarm_data" in sim and sim.swarm_data:
		var center := (from_pos + to_pos) * 0.5
		var seg_len := from_pos.distance_to(to_pos)
		var query_rad := seg_len * 0.5 + width
		var hits: PackedInt32Array = sim.spatial_hash.query_radius(Vector2(center.x, center.z), query_rad, sim.swarm_data)
		for idx in hits:
			var u_pos := Vector3(sim.swarm_data.pos_x[idx], 0.35, sim.swarm_data.pos_z[idx])
			var t: float = clampf((u_pos - from_pos).dot(seg_dir) / seg_len_sq, 0.0, 1.0)
			var proj: Vector3 = from_pos + seg_dir * t
			if u_pos.distance_to(proj) <= width:
				var killed: bool = bool(sim.apply_damage_to_unit(idx, damage))
				if killed:
					_notify_swarm_kill(idx, u_pos)


func _apply_single_target_damage(target_node: Node3D, damage: float, damage_type: int) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	var flat_arm: float = target_node.get("flat_armor") if "flat_armor" in target_node else 0.0
	var is_heroic: bool = target_node.is_in_group("heroes") or (target_node.get("is_heroic") == true if "is_heroic" in target_node else false)
	var calc_result: CombatResult = SFECombatEngine.calculate_damage(
		damage,
		damage_type,
		flat_arm,
		0,
		SFECombatEngine.StructureType.NONE,
		is_heroic,
		false,
		false
	)
	if target_node.has_method("take_damage_context"):
		target_node.take_damage_context(calc_result.damage_dealt, damage_type, false, 0)
	elif target_node.has_method("take_damage"):
		target_node.take_damage(calc_result.damage_dealt)


func _apply_gravitational_pull(center: Vector3, radius: float) -> void:
	if not is_inside_tree():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			if e.is_in_group("bosses"):
				continue
			var dist: float = center.distance_to(e.global_position)
			if dist <= radius and dist > 0.2:
				var pull_dir: Vector3 = (center - e.global_position).normalized()
				var pull_amt: float = minf(dist - 0.2, 3.5)
				if "velocity" in e:
					e.velocity += pull_dir * 12.0
				else:
					e.global_position += pull_dir * pull_amt


func get_skill_cooldown_remaining(skill_id: StringName) -> float:
	return skill_cooldowns.get(skill_id, 0.0)


func gain_experience(amount: int) -> bool:
	_ensure_components()
	var lvl_up := false
	if experience_component:
		lvl_up = experience_component.award_xp(amount)
	if hero_data:
		var hero_lvl := hero_data.add_experience(amount)
		lvl_up = lvl_up or hero_lvl
	return lvl_up


func allocate_attribute(attr_name: String, amount: int = 1) -> bool:
	if hero_data:
		return hero_data.allocate_attribute(attr_name, amount)
	return false


func move_to(target_pos: Vector3) -> void:
	focus_target = null
	if nav_agent:
		target_pos.y = 0.0
		nav_agent.target_position = target_pos


func set_attack_target(target: Node3D) -> void:
	focus_target = target


func stop_action() -> void:
	focus_target = null
	if nav_agent:
		nav_agent.target_position = global_position
	velocity = Vector3.ZERO


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected


func _on_derived_stats_updated(_stats: Dictionary) -> void:
	_apply_hero_stats_to_unit()
	apply_armory_upgrades()


func _on_armory_upgrade_purchased(_category: StringName, _tier: int, _cost: int) -> void:
	apply_armory_upgrades()


## Applies live upgrades from ArmoryUpgradeManager immediately to active combat stats
## (attack_damage, attack_cooldown, flat_armor, hp_regen) on the active hero in the SceneTree
## without reloading the scene.
func apply_armory_upgrades(upgrade_mgr: Variant = null) -> void:
	if upgrade_mgr == null:
		var ArmoryMgrScript: GDScript = load("res://core/upgrades/armory_upgrade_manager.gd") as GDScript
		if ArmoryMgrScript and ArmoryMgrScript.instance != null:
			upgrade_mgr = ArmoryMgrScript.instance
		elif is_inside_tree() and get_tree().current_scene:
			upgrade_mgr = get_tree().current_scene.get_node_or_null("ArmoryUpgradeManager")

	var b_tier: int = 0
	var a_tier: int = 0
	if upgrade_mgr != null:
		b_tier = int(upgrade_mgr.get("ballistics_tier"))
		a_tier = int(upgrade_mgr.get("armor_tier"))

	# 1. Ballistics upgrades: +15% damage, +8% attack speed, +0.6m range per tier
	var base_dmg: float = 28.0
	var base_cd: float = 0.8
	var base_rng: float = 8.5
	if hero_data != null:
		var HeroAttrCalc: GDScript = load("res://core/heroes/hero_attribute_calculator.gd") as GDScript
		if HeroAttrCalc != null:
			base_dmg = HeroAttrCalc.calculate_weapon_damage(hero_data.base_damage, hero_data.strength)
			base_cd = HeroAttrCalc.calculate_attack_cooldown(hero_data.base_cooldown, hero_data.dexterity)
		else:
			base_dmg = hero_data.weapon_damage
			base_cd = hero_data.attack_cooldown
		base_rng = hero_data.base_range if "base_range" in hero_data else hero_data.attack_range

	attack_damage = base_dmg * (1.0 + (0.15 * b_tier))
	attack_cooldown = maxf(0.05, base_cd / (1.0 + (0.08 * b_tier)))
	attack_range = base_rng + (0.6 * b_tier)

	# 2. Armor & Survival upgrades: +2.0 flat armor, +2.5 HP/s regen per tier
	var base_arm: float = hero_data.flat_armor if hero_data else 1.0
	flat_armor = base_arm + (2.0 * a_tier)

	var base_regen: float = 1.0
	if hero_data != null:
		var HeroAttrCalc: GDScript = load("res://core/heroes/hero_attribute_calculator.gd") as GDScript
		if HeroAttrCalc != null:
			base_regen = HeroAttrCalc.calculate_hp_regen(hero_data.base_hp_regen, hero_data.dexterity)
		else:
			base_regen = hero_data.hp_regen
	hp_regen = base_regen + (2.5 * a_tier)

	# Synchronize state with hero_data resource so UI panels immediately read updated stats
	if hero_data != null:
		hero_data.weapon_damage = attack_damage
		hero_data.attack_cooldown = attack_cooldown
		hero_data.attack_range = attack_range
		hero_data.effective_armor = flat_armor
		hero_data.hp_regen = hp_regen
		if a_tier > 0:
			var target_shield: float = maxf(hero_data.base_shield, 80.0 * a_tier)
			hero_data.max_shield = target_shield
			if hero_data.current_shield <= 0.0:
				hero_data.current_shield = target_shield


func _on_hero_level_up(new_lvl: int) -> void:
	if hero_data:
		current_health = minf(hero_data.max_hp, current_health + (hero_data.max_hp * 0.25))
		hero_data.current_hp = current_health
		hero_data.current_energy = minf(hero_data.max_energy, hero_data.current_energy + (hero_data.max_energy * 0.50))
		if health_bar and health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)

	_spawn_level_up_vfx(new_lvl)
	FloatingTextManager.spawn_text(self, get_world_pos(), "LEVEL UP! Lv. %d" % new_lvl, Color(1.0, 0.85, 0.2), 1.5)
	hero_leveled_up.emit(new_lvl)


## Updates visual appearance and materials of the hero model to reflect the selected archetype.
func apply_archetype_visuals(h_data: HeroData) -> void:
	if h_data == null or visual_root == null:
		return

	var arch: StringName = h_data.archetype_id
	var glb_path := ""
	var scale_vec := Vector3(1.0, 1.0, 1.0)

	match arch:
		&"marine", &"raynor":
			glb_path = "res://assets/models/heroes/raynor.glb"
			if not FileAccess.file_exists(glb_path):
				glb_path = "res://assets/models/raynor.glb"
			scale_vec = Vector3(1.0, 1.0, 1.0)
		&"marauder", &"tychus":
			glb_path = "res://assets/models/heroes/tychus.glb"
			scale_vec = Vector3(1.2, 1.15, 1.2)
		&"ghost", &"nova":
			glb_path = "res://assets/models/heroes/nova.glb"
			scale_vec = Vector3(0.95, 0.98, 0.95)
		&"zeratul":
			glb_path = "res://assets/models/heroes/zeratul.glb"
			scale_vec = Vector3(1.05, 1.05, 1.05)
		&"tassadar":
			glb_path = "res://assets/models/heroes/tassadar.glb"
			scale_vec = Vector3(1.05, 1.08, 1.05)
		&"medic", &"stetmann":
			glb_path = "res://assets/models/heroes/medic.glb"
			scale_vec = Vector3(0.98, 0.98, 0.98)
		&"harbinger":
			glb_path = "res://assets/models/heroes/harbinger.glb"
			scale_vec = Vector3(1.25, 1.25, 1.25)

	visual_root.scale = scale_vec

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.3
	mat.metallic = 0.8
	match arch:
		&"marine", &"raynor":
			mat.albedo_color = Color(0.18, 0.45, 0.9)
		&"marauder", &"tychus":
			mat.albedo_color = Color(0.25, 0.35, 0.45)
			mat.metallic = 0.95
		&"ghost", &"nova":
			mat.albedo_color = Color(0.85, 0.88, 0.92)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.85, 1.0)
			mat.emission_energy_multiplier = 0.6
		&"zeratul":
			mat.albedo_color = Color(0.12, 0.14, 0.18)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 1.0, 0.3)
			mat.emission_energy_multiplier = 1.0
		&"tassadar":
			mat.albedo_color = Color(0.85, 0.72, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(0.35, 0.75, 1.0)
			mat.emission_energy_multiplier = 0.8
		&"medic", &"stetmann":
			mat.albedo_color = Color(0.95, 0.95, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.95, 0.4)
			mat.emission_energy_multiplier = 0.7
		&"harbinger":
			mat.albedo_color = Color(1.0, 0.85, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.4, 1.0)
			mat.emission_energy_multiplier = 1.5

	var hero_scene: Node = null
	if not glb_path.is_empty() and FileAccess.file_exists(glb_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(glb_path, state) == OK:
			hero_scene = doc.generate_scene(state)
		if hero_scene == null and ResourceLoader.exists(glb_path):
			var packed: PackedScene = load(glb_path) as PackedScene
			if packed:
				hero_scene = packed.instantiate()

	if hero_scene:
		# Clean up old visual mesh and animation nodes while preserving SelectionRing
		var old_body := visual_root.get_node_or_null("BodyMesh")
		if old_body:
			old_body.name = "OldBodyMesh"
			old_body.queue_free()

		var old_rifle := visual_root.get_node_or_null("RifleMesh")
		if old_rifle:
			old_rifle.name = "OldRifleMesh"
			old_rifle.queue_free()

		var old_anim := visual_root.get_node_or_null("AnimationPlayer")
		if old_anim:
			old_anim.name = "OldAnimationPlayer"
			old_anim.queue_free()

		# Mount new meshes from GLB scene
		var new_body: Node = hero_scene.get_node_or_null("BodyMesh")
		if new_body:
			new_body.owner = null
			hero_scene.remove_child(new_body)
			visual_root.add_child(new_body)
			new_body.name = "BodyMesh"
			body_mesh = new_body as MeshInstance3D
			body_mesh.material_override = mat

		var new_rifle: Node = hero_scene.get_node_or_null("RifleMesh")
		if new_rifle:
			new_rifle.owner = null
			hero_scene.remove_child(new_rifle)
			visual_root.add_child(new_rifle)
			new_rifle.name = "RifleMesh"
			rifle_mesh = new_rifle as MeshInstance3D

		var new_anim: Node = hero_scene.get_node_or_null("AnimationPlayer")
		if new_anim:
			new_anim.owner = null
			hero_scene.remove_child(new_anim)
			visual_root.add_child(new_anim)
			new_anim.name = "AnimationPlayer"
			anim_player = new_anim as AnimationPlayer

		# Ensure MuzzleFlash is attached under RifleMesh
		if rifle_mesh:
			var flash: MeshInstance3D = rifle_mesh.get_node_or_null("MuzzleFlash") as MeshInstance3D
			if flash == null:
				flash = MeshInstance3D.new()
				flash.name = "MuzzleFlash"
				var box := BoxMesh.new()
				box.size = Vector3(0.08, 0.08, 0.16)
				var flash_mat := StandardMaterial3D.new()
				flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flash_mat.albedo_color = Color(1.0, 0.9, 0.4)
				box.material = flash_mat
				flash.mesh = box
				flash.position = Vector3(0, 0, -0.45)
				flash.visible = false
				rifle_mesh.add_child(flash)
			muzzle_flash = flash

		hero_scene.queue_free()

		if is_instance_valid(anim_player) and anim_player.has_animation("idle"):
			anim_player.play("idle")
	else:
		# Fallback: override material on existing BodyMesh if GLB is missing
		var body_mesh_inst: MeshInstance3D = visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
		if body_mesh_inst != null:
			body_mesh_inst.material_override = mat


# -----------------------------------------------------------------------------
# Headless-Safe Procedural Visual Effects
# -----------------------------------------------------------------------------

func _spawn_stimpack_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	HeroAbilityVFX.spawn_stimpack(self)


func _spawn_blink_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_blink(p, from_p, to_p)


func _spawn_psionic_storm_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_psionic_storm(p, center, radius)


func _spawn_heal_beam_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	var dummy_src := Node3D.new()
	var dummy_dst := Node3D.new()
	p.add_child(dummy_src)
	p.add_child(dummy_dst)
	dummy_src.global_position = from_p
	dummy_dst.global_position = to_p
	HeroAbilityVFX.spawn_heal_beam(p, dummy_src, dummy_dst, 0.4)
	var tw := p.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(dummy_src): dummy_src.queue_free()
		if is_instance_valid(dummy_dst): dummy_dst.queue_free()
	)


func _spawn_shield_bubble_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	HeroAbilityVFX.spawn_plasma_shield(self, 3.5)


func _spawn_shadow_cleave_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_shadow_cleave(p, center, radius)


func _spawn_grenade_explosion_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_shredder_grenade(p, center, radius)


func _spawn_snipe_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_snipe(p, from_p, to_p)


func _spawn_cloak_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	HeroAbilityVFX.apply_tactical_cloak(self, 15.0)


func _spawn_penetrating_round_vfx(from_p: Vector3, dir: Vector3, dist: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_penetrating_round(p, from_p, dir, dist)


func _spawn_orbital_bombardment_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_orbital_bombardment(p, center, radius)


func _spawn_overkill_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	HeroAbilityVFX.spawn_overkill(self, 6.0)


func _spawn_defensive_matrix_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	HeroAbilityVFX.spawn_defensive_matrix(self, 7.0)


func _spawn_celestial_singularity_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_celestial_singularity(p, center, radius)


func _spawn_dimensional_beam_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p: Node = get_parent() if get_parent() else self
	HeroAbilityVFX.spawn_dimensional_beam(p, from_p, to_p)


func _spawn_level_up_vfx(new_lvl: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.85
	cyl.height = 3.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.88, 0.3, 0.85)
	column.mesh = cyl
	column.material_override = mat
	add_child(column)
	column.position = Vector3(0, 1.75, 0)
	var tw: Tween = column.create_tween()
	tw.parallel().tween_property(column, "position:y", 2.8, 0.7)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.tween_callback(column.queue_free)
