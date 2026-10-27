class_name SpawnerNode
extends StaticBody3D

## SpawnerNode - SFE5 Procedural Chain Spawner Entity (Tasks 3.1, 3.3, 3.5).
## SFE5 Rules:
## 1. 20s horde spawn cycle.
## 2. Invulnerable when LOCKED (visual shield dome + padlock indicator).
## 3. Unlocks into ACTIVE when predecessor is destroyed.
## 4. Pauses production if living enemy budget reaches 300.
## 5. Upon destruction: awards bounty (x8 Structure category multiplier) and mutates class.

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")
const IncomeFormula = preload("res://core/economy/income_formula.gd")
const IncomeParams = preload("res://core/economy/income_params.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")
const SpawnerData = preload("res://core/data/spawner_data.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")

enum State {
	LOCKED = 0,
	ACTIVE = 1,
	DESTROYED = 2
}

@export_group("Spawner Configuration")
@export var spawner_id: StringName = &"spawner_01"
@export var spawner_name: String = "Nido Zergling"
@export var family: String = "zergling"
@export var archetype_id: int = 0
@export var group_size: int = 6
@export var cycle_seconds: float = 20.0
@export var max_health: float = 1800.0:
	set(val):
		max_health = val
		current_health = val
@export var structure_armor: float = 6.0
@export var spawn_radius: float = 3.5
@export var initial_state: State = State.LOCKED
@export var spawner_data: SpawnerData = null

var current_state: State = State.LOCKED
var current_health: float = 1800.0
var cycle_timer: float = 0.0

var budget_manager: EnemyBudgetManager = null
var swarm_simulation: Node = null

# Visual Nodes
var visual_mesh: Node3D = null
var shield_mesh: MeshInstance3D = null
var lock_label: Label3D = null
var health_bar_mesh: MeshInstance3D = null
var health_bar_bg: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

signal spawner_state_changed(spawner: SpawnerNode, new_state: State)
signal spawner_unlocked(spawner_id: StringName)
signal spawner_destroyed(spawner_id: StringName, family: String)
signal spawner_spawn_cycle_executed(spawner_id: StringName, unit_count: int)
signal health_changed(current: float, maximum: float)


func _ready() -> void:
	add_to_group("spawners")
	add_to_group("structures")
	add_to_group("enemies")
	
	if spawner_data:
		_apply_spawner_data(spawner_data)
	else:
		current_health = max_health
	
	_setup_collision()
	_setup_visuals()
	
	set_spawner_state(initial_state)


func _apply_spawner_data(data: SpawnerData) -> void:
	spawner_id = data.id
	spawner_name = data.spawner_name
	family = data.family
	group_size = data.group_size
	cycle_seconds = data.cycle_seconds
	max_health = data.structure_health
	current_health = data.structure_health
	structure_armor = data.structure_armor
	
	var arch_map: Dictionary = {
		"zergling": 0,
		"roach": 1,
		"baneling": 2,
		"hydra": 3,
		"hydralisk": 3,
		"ultralisk": 4
	}
	archetype_id = arch_map.get(family.to_lower(), 0)


func _setup_collision() -> void:
	collision_layer = 4 # Enemies / Structures layer
	collision_mask = 3  # Heroes / Projectiles layer
	
	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 3.5, 3.2)
	collision_shape.shape = box
	collision_shape.position = Vector3(0.0, 1.75, 0.0)
	add_child(collision_shape)


func _setup_visuals() -> void:
	# 1. Spawner Structure Mesh (Zerg/Alien hive spire)
	visual_mesh = Node3D.new()
	visual_mesh.name = "VisualRoot"
	add_child(visual_mesh)
	
	var base_mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 2.0
	cylinder.height = 3.0
	base_mesh_inst.mesh = cylinder
	base_mesh_inst.position = Vector3(0.0, 1.5, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.12, 0.18) # Fleshy hive crimson
	mat.roughness = 0.45
	mat.metallic = 0.1
	base_mesh_inst.material_override = mat
	visual_mesh.add_child(base_mesh_inst)
	
	# Spire cap
	var cap_inst := MeshInstance3D.new()
	var cap_cone := CylinderMesh.new()
	cap_cone.top_radius = 0.2
	cap_cone.bottom_radius = 1.3
	cap_cone.height = 1.2
	cap_inst.mesh = cap_cone
	cap_inst.position = Vector3(0.0, 3.4, 0.0)
	
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.5, 0.08, 0.1)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.8, 0.15, 0.2) * 0.7
	cap_inst.material_override = cap_mat
	visual_mesh.add_child(cap_inst)
	
	# 2. Locked Shield Dome (Task 3.3)
	shield_mesh = MeshInstance3D.new()
	shield_mesh.name = "ShieldDome"
	var sphere := SphereMesh.new()
	sphere.radius = 2.4
	sphere.height = 4.8
	shield_mesh.mesh = sphere
	shield_mesh.position = Vector3(0.0, 2.0, 0.0)
	
	var shield_mat := StandardMaterial3D.new()
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.albedo_color = Color(0.2, 0.7, 1.0, 0.45) # Pulsing cyan energy
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.3, 0.8, 1.0)
	shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_mesh.material_override = shield_mat
	add_child(shield_mesh)
	
	# 3. Locked Status Billboard / Tooltip
	lock_label = Label3D.new()
	lock_label.name = "LockIndicator"
	lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lock_label.position = Vector3(0.0, 4.6, 0.0)
	lock_label.font_size = 28
	lock_label.outline_size = 8
	lock_label.modulate = Color(1.0, 0.35, 0.35)
	lock_label.outline_modulate = Color(0.0, 0.0, 0.0)
	lock_label.text = "🔒 BLOQUEADO"
	add_child(lock_label)
	
	# 4. 3D World-Space Health Bar
	_setup_health_bar()


func _setup_health_bar() -> void:
	health_bar_bg = MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(2.6, 0.25)
	health_bar_bg.mesh = bg_quad
	health_bar_bg.position = Vector3(0.0, 4.2, 0.0)
	
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_bg.material_override = bg_mat
	add_child(health_bar_bg)
	
	health_bar_mesh = MeshInstance3D.new()
	var fg_quad := QuadMesh.new()
	fg_quad.size = Vector2(2.5, 0.2)
	health_bar_mesh.mesh = fg_quad
	health_bar_mesh.position = Vector3(0.0, 4.2, 0.01)
	
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.85, 0.15, 0.15)
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_mesh.material_override = fg_mat
	add_child(health_bar_mesh)


func set_spawner_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.LOCKED:
			if shield_mesh:
				shield_mesh.visible = true
			if lock_label:
				lock_label.visible = true
				lock_label.text = "🔒 BLOQUEADO"
			if health_bar_bg:
				health_bar_bg.visible = false
			if health_bar_mesh:
				health_bar_mesh.visible = false
		State.ACTIVE:
			if shield_mesh:
				shield_mesh.visible = false
			if lock_label:
				lock_label.visible = false
			if health_bar_bg:
				health_bar_bg.visible = true
			if health_bar_mesh:
				health_bar_mesh.visible = true
			cycle_timer = 0.0
		State.DESTROYED:
			if shield_mesh:
				shield_mesh.visible = false
			if lock_label:
				lock_label.visible = true
				lock_label.text = "💀 DESTRUIDO"
				lock_label.modulate = Color(0.6, 0.6, 0.6)
			if health_bar_bg:
				health_bar_bg.visible = false
			if health_bar_mesh:
				health_bar_mesh.visible = false
			if collision_shape:
				collision_shape.disabled = true
			if visual_mesh:
				visual_mesh.visible = false
	
	spawner_state_changed.emit(self, current_state)


func unlock() -> void:
	if current_state == State.LOCKED:
		set_spawner_state(State.ACTIVE)
		spawner_unlocked.emit(spawner_id)
		if is_inside_tree():
			FloatingTextManager.spawn_text(
				self,
				global_position + Vector3(0.0, 3.5, 0.0),
				"¡ENGENDRADOR DESBLOQUEADO!",
				Color(1.0, 0.85, 0.2)
			)


func _physics_process(delta: float) -> void:
	if current_state != State.ACTIVE:
		return
	
	cycle_timer += delta
	if cycle_timer >= cycle_seconds:
		_try_spawn_cycle()


func _try_spawn_cycle() -> void:
	# Task 3.4: Budget clamp: if living enemies >= 300, pause production
	if budget_manager and not budget_manager.can_spawn(group_size):
		# Budget full: remain at full cycle timer until budget frees up
		cycle_timer = cycle_seconds
		return
	
	cycle_timer = 0.0
	
	if swarm_simulation and is_instance_valid(swarm_simulation):
		swarm_simulation.spawn_wave(archetype_id, group_size, global_position, spawn_radius)
		spawner_spawn_cycle_executed.emit(spawner_id, group_size)


## Incoming damage handler adhering to SFE5 combat rules
func take_damage(raw_amount: float, attacker: Node = null) -> float:
	if current_state == State.DESTROYED:
		return 0.0
	
	# Task 3.3: Invulnerable when LOCKED
	if current_state == State.LOCKED:
		if is_inside_tree():
			FloatingTextManager.spawn_text(
				self,
				global_position + Vector3(0.0, 3.0, 0.0),
				"¡INVULNERABLE!",
				Color(0.4, 0.8, 1.0)
			)
		return 0.0
	
	var is_attacker_armor_piercing := false
	if attacker and "ignores_armor" in attacker:
		is_attacker_armor_piercing = attacker.ignores_armor
	
	var result := SFECombatEngine.calculate_damage(
		raw_amount,
		SFECombatEngine.DamageType.PHYSICAL,
		structure_armor,
		0, # upgrade level
		SFECombatEngine.StructureType.OTHER,
		false, # is_heroic
		false, # is_aoe
		false, # is_invulnerable
		0.0,   # shield_hp
		current_health,
		SFECombatEngine.TargetTag.STRUCTURE,
		is_attacker_armor_piercing
	)
	
	current_health = maxf(0.0, current_health - result.damage_dealt)
	_update_health_bar()
	health_changed.emit(current_health, max_health)
	
	if is_inside_tree():
		FloatingTextManager.spawn_text(
			self,
			global_position + Vector3(0.0, 2.0, 0.0),
			"-%d" % int(result.damage_dealt),
			Color(1.0, 0.4, 0.4)
		)
	
	if current_health <= 0.0:
		_destroy(attacker)
	
	return result.damage_dealt


func _update_health_bar() -> void:
	if health_bar_mesh:
		var ratio := clampf(current_health / max_health, 0.0, 1.0)
		var quad: QuadMesh = health_bar_mesh.mesh as QuadMesh
		if quad:
			quad.size = Vector2(2.5 * ratio, 0.2)
			health_bar_mesh.position.x = -1.25 * (1.0 - ratio)


func _destroy(_killer: Node) -> void:
	set_spawner_state(State.DESTROYED)
	
	# Calculate SFE5 Bounty (Structure multiplier x8)
	var params := IncomeParams.new()
	params.base_health = max_health
	params.category = "structure"
	params.weapon_damage = 0.0
	var awarded_bounty := IncomeFormula.compute(params)
	
	# Award to economy manager if available
	if is_inside_tree():
		var tree := get_tree()
		if tree and tree.root:
			var econ = tree.root.find_child("EconomyManager", true, false)
			if econ and econ.has_method("add_minerals"):
				econ.add_minerals(awarded_bounty)
		FloatingTextManager.spawn_text(
			self,
			global_position + Vector3(0.0, 3.0, 0.0),
			"+%d 💎 (¡ESTRUCTURA!)" % awarded_bounty,
			Color(0.2, 1.0, 0.3) # Green for Structure
		)
	
	spawner_destroyed.emit(spawner_id, family)
	
	var loop := Engine.get_main_loop()
	if loop and "root" in loop and loop.root:
		var bus: Node = loop.root.get_node_or_null("SignalBus")
		if bus and bus.has_signal("structure_destroyed"):
			bus.structure_destroyed.emit(self)
