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

signal skill_cast(skill: HeroSkillData, target: Variant)
signal hero_leveled_up(new_level: int)

@export var hero_data: HeroData

# Node References (if present in visual scene)
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var selection_ring: MeshInstance3D = get_node_or_null("VisualRoot/SelectionRing")
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var health_bar: Node = get_node_or_null("HealthBar3D")
@onready var muzzle_flash: MeshInstance3D = get_node_or_null("VisualRoot/RifleMesh/MuzzleFlash")

# Combat & Utility Properties
var current_health: float = 550.0
var max_health: float = 550.0
var move_speed: float = 5.2
var attack_range: float = 8.5
var attack_damage: float = 28.0
var attack_cooldown: float = 0.8

var is_selected: bool = false
var focus_target: Node3D = null
var _attack_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Subsystems
var buff_engine: SFEBuffEngine = null
var skill_cooldowns: Dictionary = {} # skill_id -> remaining_seconds

# Target classification bitmask tagged HEROIC
var target_tags: int = CombatTypes.TargetTag.HEROIC | CombatTypes.TargetTag.BIOLOGICAL | CombatTypes.TargetTag.GROUND
var is_heroic: bool = true

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

func _bind_hero_data() -> void:
	if hero_data == null:
		return

	if not hero_data.derived_stats_updated.is_connected(_on_derived_stats_updated):
		hero_data.derived_stats_updated.connect(_on_derived_stats_updated)
	if not hero_data.level_up.is_connected(_on_hero_level_up):
		hero_data.level_up.connect(_on_hero_level_up)

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

	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)

func _physics_process(delta: float) -> void:
	# 1. Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = maxf(0.0, _attack_timer - delta)

	# 2. Buff engine tick
	if buff_engine:
		buff_engine.tick(delta)

	# 3. HP and Energy regeneration from derived RPG attributes
	if hero_data:
		var hp_regen_rate: float = hero_data.hp_regen * (buff_engine.get_total_stat_multiplier("hp_regen") if buff_engine else 1.0)
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
			return
		else:
			_stop_movement(delta)
			_look_at_target(focus_target.global_position, delta)
			if _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				_fire_at(focus_target)
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
		return

	# 7. Stationary Behavior: Auto-Attack nearby enemies within attack_range
	_stop_movement(delta)
	var enemy: Node3D = _find_nearest_enemy_in_range()
	if enemy:
		_look_at_target(enemy.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_fire_at(enemy)

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

## Routes damage calculation through SFECombatEngine with HEROIC tag and invulnerability checks.
func take_damage_context(
	raw_amount: float,
	damage_type: int = CombatTypes.DamageType.PHYSICAL,
	is_aoe: bool = false,
	armor_upgrade_level: int = 0
) -> CombatResult:
	var is_invuln: bool = buff_engine.is_invulnerable() if buff_engine else false
	var hero_armor: float = hero_data.flat_armor if hero_data else 0.0
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

	if hero_data and result.absorbed > 0.0:
		hero_data.current_shield = maxf(0.0, hero_data.current_shield - result.absorbed)

	current_health = maxf(0.0, current_health - result.damage_dealt)
	if hero_data:
		hero_data.current_hp = current_health

	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)

	if is_inside_tree() and has_node("/root/SignalBus"):
		get_node("/root/SignalBus").emit_signal("unit_health_changed", self, current_health, max_health)

	if current_health <= 0.0:
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

	var base_dmg: float = hero_data.weapon_damage if hero_data else attack_damage
	var buff_mult: float = buff_engine.get_total_stat_multiplier("attack_damage") if buff_engine else 1.0
	var final_damage: float = base_dmg * buff_mult

	if target.has_method("take_damage_context"):
		target.take_damage_context(final_damage, CombatTypes.DamageType.PHYSICAL, false, 0)
	elif target.has_method("take_damage"):
		target.take_damage(final_damage)

	if muzzle_flash:
		muzzle_flash.visible = true
		var tween: Tween = create_tween()
		tween.tween_interval(0.06)
		tween.tween_callback(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)


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
			_spawn_stimpack_vfx()

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

		&"psionic_storm":
			var cur_pos: Vector3 = get_world_pos()
			var storm_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 6.0))
			_spawn_psionic_storm_vfx(storm_center, 4.5)
			_apply_aoe_damage(storm_center, 4.5, skill.base_power, CombatTypes.DamageType.SPELL)

		&"heal_beam":
			var cur_pos: Vector3 = get_world_pos()
			var lowest_ally: Node3D = null
			var lowest_pct: float = 1.0
			var allies: Array[Node] = get_tree().get_nodes_in_group("allies") if is_inside_tree() else []
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

		&"plasma_shield", &"defensive_matrix":
			hero_data.current_shield = minf(hero_data.max_shield if hero_data.max_shield > 0.0 else 200.0, hero_data.current_shield + 150.0)
			_spawn_shield_bubble_vfx()

		&"shadow_cleave":
			var cur_pos: Vector3 = get_world_pos()
			_spawn_shadow_cleave_vfx(cur_pos, 3.2)
			_apply_aoe_damage(cur_pos, 3.2, skill.base_power, CombatTypes.DamageType.PHYSICAL)

		&"frag_grenade", &"shredder_grenade":
			var cur_pos: Vector3 = get_world_pos()
			var nade_center: Vector3 = target if target is Vector3 else (cur_pos + (get_facing_direction() * 6.0))
			_spawn_grenade_explosion_vfx(nade_center, skill.area_radius if skill.area_radius > 0.0 else 3.5)
			_apply_aoe_damage(nade_center, skill.area_radius if skill.area_radius > 0.0 else 3.5, skill.base_power, skill.damage_type)

		_:
			# Generic fallback execution
			if skill.base_power > 0.0:
				if target is Node3D and is_instance_valid(target):
					if target.has_method("take_damage_context"):
						target.take_damage_context(skill.base_power, skill.damage_type, skill.area_radius > 0.0)
					elif target.has_method("take_damage"):
						target.take_damage(skill.base_power)
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
				if e.has_method("take_damage_context"):
					e.take_damage_context(damage, damage_type, true)
				elif e.has_method("take_damage"):
					e.take_damage(damage)


func get_skill_cooldown_remaining(skill_id: StringName) -> float:
	return skill_cooldowns.get(skill_id, 0.0)


func gain_experience(amount: int) -> bool:
	if hero_data:
		return hero_data.add_experience(amount)
	return false


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


func die() -> void:
	if is_inside_tree() and has_node("/root/SignalBus"):
		get_node("/root/SignalBus").emit_signal("unit_died", self)
	queue_free()


func _on_derived_stats_updated(_stats: Dictionary) -> void:
	_apply_hero_stats_to_unit()


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
	var body_mesh_inst: MeshInstance3D = visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
	if body_mesh_inst == null:
		return

	var arch: StringName = h_data.archetype_id
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.3
	mat.metallic = 0.8

	match arch:
		&"marine", &"raynor":
			visual_root.scale = Vector3(1.0, 1.0, 1.0)
			mat.albedo_color = Color(0.18, 0.45, 0.9)
		&"marauder", &"tychus":
			visual_root.scale = Vector3(1.2, 1.15, 1.2)
			mat.albedo_color = Color(0.25, 0.35, 0.45)
			mat.metallic = 0.95
		&"ghost", &"nova":
			visual_root.scale = Vector3(0.95, 0.98, 0.95)
			mat.albedo_color = Color(0.85, 0.88, 0.92)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.85, 1.0)
			mat.emission_energy_multiplier = 0.6
		&"zeratul":
			visual_root.scale = Vector3(1.05, 1.05, 1.05)
			mat.albedo_color = Color(0.12, 0.14, 0.18)
			mat.emission_enabled = true
			mat.emission = Color(0.3, 1.0, 0.3)
			mat.emission_energy_multiplier = 1.0
		&"tassadar":
			visual_root.scale = Vector3(1.05, 1.08, 1.05)
			mat.albedo_color = Color(0.85, 0.72, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(0.35, 0.75, 1.0)
			mat.emission_energy_multiplier = 0.8
		&"medic", &"stetmann":
			visual_root.scale = Vector3(0.98, 0.98, 0.98)
			mat.albedo_color = Color(0.95, 0.95, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.95, 0.4)
			mat.emission_energy_multiplier = 0.7
		&"harbinger":
			visual_root.scale = Vector3(1.25, 1.25, 1.25)
			mat.albedo_color = Color(1.0, 0.85, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.4, 1.0)
			mat.emission_energy_multiplier = 1.5

	body_mesh_inst.material_override = mat


# -----------------------------------------------------------------------------
# Headless-Safe Procedural Visual Effects
# -----------------------------------------------------------------------------

func _spawn_stimpack_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.25, 0.25, 0.9)
	ring.mesh = torus
	ring.material_override = mat
	add_child(ring)
	ring.position = Vector3(0, 0.9, 0)
	var tw: Tween = ring.create_tween()
	tw.parallel().tween_property(ring, "scale", Vector3(1.8, 1.8, 1.8), 0.35)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(ring.queue_free)


func _spawn_blink_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for p in [from_p, to_p]:
		var flash := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.6
		sphere.height = 1.2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(0.2, 0.9, 0.5, 0.95)
		flash.mesh = sphere
		flash.material_override = mat
		get_parent().add_child(flash)
		flash.global_position = p + Vector3(0, 0.8, 0)
		var tw: Tween = flash.create_tween()
		tw.parallel().tween_property(flash, "scale", Vector3(1.6, 1.6, 1.6), 0.25)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tw.tween_callback(flash.queue_free)


func _spawn_psionic_storm_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var storm := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.4, 0.5, 1.0, 0.65)
	storm.mesh = cyl
	storm.material_override = mat
	get_parent().add_child(storm)
	storm.global_position = center + Vector3(0, 0.3, 0)
	var tw: Tween = storm.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.8)
	tw.tween_callback(storm.queue_free)


func _spawn_heal_beam_vfx(from_p: Vector3, to_p: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = from_p.distance_to(to_p)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.2, 0.95, 0.4, 0.95)
	beam.mesh = cyl
	beam.material_override = mat
	get_parent().add_child(beam)
	beam.global_position = (from_p + to_p) * 0.5
	beam.look_at(to_p, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	var tw: Tween = beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(beam.queue_free)


func _spawn_shield_bubble_vfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var bubble := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.55)
	bubble.mesh = sphere
	bubble.material_override = mat
	add_child(bubble)
	bubble.position = Vector3(0, 1.0, 0)
	var tw: Tween = bubble.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(bubble.queue_free)


func _spawn_shadow_cleave_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var disk := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.7
	torus.outer_radius = radius
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.2, 1.0, 0.5, 0.9)
	disk.mesh = torus
	disk.material_override = mat
	get_parent().add_child(disk)
	disk.global_position = center + Vector3(0, 0.8, 0)
	var tw: Tween = disk.create_tween()
	tw.parallel().tween_property(disk, "scale", Vector3(1.3, 1.3, 1.3), 0.25)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(disk.queue_free)


func _spawn_grenade_explosion_vfx(center: Vector3, radius: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var blast := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.6
	sphere.height = radius * 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	blast.mesh = sphere
	blast.material_override = mat
	get_parent().add_child(blast)
	blast.global_position = center + Vector3(0, 0.5, 0)
	var tw: Tween = blast.create_tween()
	tw.parallel().tween_property(blast, "scale", Vector3(1.5, 1.5, 1.5), 0.3)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(blast.queue_free)


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
