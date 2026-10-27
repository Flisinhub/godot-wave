class_name BaseUnit3D
extends CharacterBody3D

## BaseUnit3D - Standard RTS Unit with Navigation, Auto-Attack, Focus Fire & Micromanagement Support

const EliteComponent = preload("res://core/components/elite_component.gd")
const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const AbilityComponent = preload("res://core/components/ability_component.gd")
const ExperienceComponent = preload("res://core/components/experience_component.gd")
const CategoryRingStyler = preload("res://core/vfx/category_ring_styler.gd")

@export var unit_data: UnitData

@onready var visual_root: Node3D = $VisualRoot
@onready var selection_ring: MeshInstance3D = $VisualRoot/SelectionRing
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: HealthBar3D = $HealthBar3D
@onready var muzzle_flash: MeshInstance3D = $VisualRoot/RifleMesh/MuzzleFlash
@onready var anim_player: AnimationPlayer = $VisualRoot.get_node_or_null("AnimationPlayer")
@onready var body_mesh: MeshInstance3D = $VisualRoot.get_node_or_null("BodyMesh")
@onready var rifle_mesh: MeshInstance3D = $VisualRoot.get_node_or_null("RifleMesh")

var current_health: float = 45.0
var max_health: float = 45.0
var move_speed: float = 5.0
var attack_range: float = 10.0
var attack_damage: float = 7.0
var attack_cooldown: float = 0.6

var is_selected: bool = false
var focus_target: Node3D = null
var _attack_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var elite_component: EliteComponent = null
var stats_component: StatsComponent = null
var buff_component: BuffComponent = null
var ability_component: AbilityComponent = null
var experience_component: ExperienceComponent = null


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _ensure_elite_component() -> EliteComponent:
	if not elite_component:
		elite_component = get_node_or_null("EliteComponent") as EliteComponent
		if not elite_component:
			elite_component = EliteComponent.new()
			elite_component.name = "EliteComponent"
			add_child(elite_component)
	return elite_component


func _ensure_all_components() -> void:
	_ensure_elite_component()
	if not stats_component:
		stats_component = get_node_or_null("StatsComponent") as StatsComponent
		if not stats_component:
			stats_component = StatsComponent.new()
			stats_component.name = "StatsComponent"
			add_child(stats_component)
		stats_component.base_max_hp = max_health
		stats_component.base_damage = attack_damage
		stats_component.base_attack_period = attack_cooldown
		stats_component.base_move_speed = move_speed
		stats_component.recalculate()
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


func _ready() -> void:
	add_to_group("allies")
	_ensure_all_components()
	
	if unit_data:
		max_health = unit_data.max_health
		current_health = max_health
		move_speed = unit_data.move_speed
		attack_range = unit_data.attack_range
		attack_damage = unit_data.attack_damage
		attack_cooldown = unit_data.attack_cooldown
	
	if selection_ring:
		selection_ring.visible = false

	if health_bar:
		health_bar.setup(current_health, max_health)
		
	if muzzle_flash:
		muzzle_flash.visible = false
	
	# Configure navigation agent for responsive RTS movement and RVO local avoidance
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


func _ensure_animation_player() -> void:
	if is_instance_valid(anim_player) and not anim_player.get_animation_list().is_empty():
		return
	var glb_path := "res://assets/models/marine.glb"
	if FileAccess.file_exists(glb_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(glb_path, state) == OK:
			var scene := doc.generate_scene(state)
			if scene:
				var glb_anim := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
				if glb_anim:
					if not is_instance_valid(anim_player) and is_instance_valid(visual_root):
						anim_player = AnimationPlayer.new()
						anim_player.name = "AnimationPlayer"
						visual_root.add_child(anim_player)
					for lib_name in glb_anim.get_animation_library_list():
						var lib := glb_anim.get_animation_library(lib_name)
						if not anim_player.has_animation_library(lib_name):
							anim_player.add_animation_library(lib_name, lib)
				scene.queue_free()


func _physics_process(delta: float) -> void:
	# Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = max(0.0, _attack_timer - delta)

	# Handle Focus Target if assigned
	if is_instance_valid(focus_target):
		var dist: float = global_position.distance_to(focus_target.global_position)
		if dist > attack_range:
			# Target outside range, move closer
			_navigate_towards(focus_target.global_position, delta)
			_update_animations()
			return
		else:
			# Target within range: stop moving and shoot
			_stop_movement(delta)
			_look_at_target(focus_target.global_position, delta)
			if _attack_timer <= 0.0:
				_attack_timer = attack_cooldown
				_fire_at(focus_target)
			_update_animations()
			return
	else:
		focus_target = null

	# Handle normal movement navigation
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos: Vector3 = nav_agent.get_next_path_position()
		var move_dir: Vector3 = (next_pos - global_position)
		move_dir.y = 0.0

		if move_dir.length_squared() > 0.001:
			move_dir = move_dir.normalized()
			var intended_velocity: Vector3 = move_dir * move_speed
			if nav_agent.avoidance_enabled:
				nav_agent.set_velocity(intended_velocity)
			else:
				_apply_movement_velocity(intended_velocity, delta)
		else:
			_stop_movement(delta)
		_update_animations()
		return

	# Stationary behavior: Auto-Attack nearby enemies within attack_range
	_stop_movement(delta)
	var enemy: Node3D = _find_nearest_enemy_in_range()
	if enemy:
		_look_at_target(enemy.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_fire_at(enemy)
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


func _fire_at(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	var bonus_dmg: float = elite_component.get_bonus_damage() if elite_component else 0.0
	var final_damage: float = attack_damage + bonus_dmg
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
	
	if is_instance_valid(anim_player):
		if anim_player.has_animation("shoot"):
			anim_player.play("shoot")
		elif anim_player.has_animation("attack"):
			anim_player.play("attack")
	
	# Muzzle flash visual effect
	if muzzle_flash:
		muzzle_flash.visible = true
		var tween: Tween = create_tween()
		if tween:
			tween.tween_interval(0.06)
			tween.tween_callback(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)


func _find_nearest_enemy_in_range() -> Node3D:
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


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_apply_movement_velocity(safe_velocity, get_physics_process_delta_time())


func _apply_movement_velocity(vel: Vector3, delta: float) -> void:
	if vel.length_squared() > 0.01:
		var target_angle_y: float = atan2(-vel.x, -vel.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 12.0)
	
	velocity.x = vel.x
	velocity.z = vel.z
	move_and_slide()


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
		if selected:
			var cat: String = "elite" if (elite_component and elite_component.is_elite) else (unit_data.category if unit_data else "normal")
			CategoryRingStyler.apply_ring_style(selection_ring, cat)


func promote_to_elite() -> void:
	_ensure_elite_component().promote_to_elite()


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar:
		health_bar.update_health(current_health, max_health)
	var sb := _get_signal_bus()
	if sb:
		sb.emit_signal("unit_health_changed", self, current_health, max_health)
	if current_health <= 0.0:
		die()


func die() -> void:
	var sb := _get_signal_bus()
	if sb:
		sb.emit_signal("unit_died", self)
	if is_instance_valid(anim_player) and anim_player.has_animation("death") and DisplayServer.get_name() != "headless":
		set_physics_process(false)
		var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred("disabled", true)
		anim_player.play("death")
		anim_player.animation_finished.connect(func(_a): queue_free(), CONNECT_ONE_SHOT)
	else:
		queue_free()
