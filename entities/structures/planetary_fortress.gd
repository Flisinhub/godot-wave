class_name PlanetaryFortress
extends StaticBody3D

## PlanetaryFortress - Central Headquarters and Defensive Citadel for SFE5 (Task 3.17).
## SFE5 Rules:
## 1. 3000 HP, 3 Armor.
## 2. Equipped with twin IBIS Cannons to bombard encroaching swarm enemies.
## 3. Immediate Defeat when destroyed.

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")

@export var max_health: float = 3000.0
@export var structure_armor: float = 3.0
@export var structure_name: String = "Planetary Fortress"
@export var cannon_range: float = 14.0
@export var cannon_damage: float = 40.0
@export var cannon_cooldown: float = 1.8

var current_health: float = 3000.0
var _cannon_timer: float = 0.0

var swarm_simulation: Node = null
var health_bar: MeshInstance3D = null
var health_bar_bg: MeshInstance3D = null
var cannon_barrel: Node3D = null

signal fortress_damaged(current_hp: float, max_hp: float)
signal fortress_destroyed()


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _ready() -> void:
	add_to_group("structures")
	add_to_group("command_centers")
	add_to_group("allies")
	
	current_health = max_health
	_setup_collision()
	_setup_visuals()


func _setup_collision() -> void:
	collision_layer = 2 # Allies / Structures
	collision_mask = 5  # Enemies / Swarm
	
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.5, 6.0)
	col.shape = box
	col.position = Vector3(0.0, 2.25, 0.0)
	add_child(col)


func _setup_visuals() -> void:
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	
	# Fortress Body
	var body_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(5.5, 3.6, 5.5)
	body_inst.mesh = box_mesh
	body_inst.position = Vector3(0.0, 1.8, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.36) # Terran steel blue
	mat.metallic = 0.8
	mat.roughness = 0.35
	body_inst.material_override = mat
	visual_root.add_child(body_inst)
	
	# Armored Roof Bunker
	var roof_inst := MeshInstance3D.new()
	var roof_box := BoxMesh.new()
	roof_box.size = Vector3(3.6, 1.0, 3.6)
	roof_inst.mesh = roof_box
	roof_inst.position = Vector3(0.0, 4.1, 0.0)
	
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.15, 0.18, 0.22)
	roof_mat.metallic = 0.9
	roof_inst.material_override = roof_mat
	visual_root.add_child(roof_inst)
	
	# Twin IBIS Cannons on roof
	cannon_barrel = Node3D.new()
	cannon_barrel.name = "IBISCannon"
	cannon_barrel.position = Vector3(0.0, 4.6, 0.0)
	
	var barrel_left := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.18
	cyl.height = 1.8
	barrel_left.mesh = cyl
	barrel_left.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	barrel_left.position = Vector3(-0.6, 0.0, 0.8)
	cannon_barrel.add_child(barrel_left)
	
	var barrel_right := MeshInstance3D.new()
	barrel_right.mesh = cyl
	barrel_right.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	barrel_right.position = Vector3(0.6, 0.0, 0.8)
	cannon_barrel.add_child(barrel_right)
	
	visual_root.add_child(cannon_barrel)
	
	# 3D Health Bar
	_setup_health_bar()


func _setup_health_bar() -> void:
	health_bar_bg = MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(4.2, 0.35)
	health_bar_bg.mesh = bg_quad
	health_bar_bg.position = Vector3(0.0, 5.8, 0.0)
	
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.08, 0.9)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_bg.material_override = bg_mat
	add_child(health_bar_bg)
	
	health_bar = MeshInstance3D.new()
	var fg_quad := QuadMesh.new()
	fg_quad.size = Vector2(4.0, 0.28)
	health_bar.mesh = fg_quad
	health_bar.position = Vector3(0.0, 5.8, 0.01)
	
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.15, 0.85, 0.3) # Healthy Terran Green
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar.material_override = fg_mat
	add_child(health_bar)


func set_simulation(sim: Node) -> void:
	swarm_simulation = sim


func _physics_process(delta: float) -> void:
	_cannon_timer += delta
	if _cannon_timer >= cannon_cooldown:
		_try_fire_ibis_cannon()


func _try_fire_ibis_cannon() -> void:
	if not swarm_simulation or not is_instance_valid(swarm_simulation):
		return
	
	# Check for nearest swarm enemy within cannon range
	var my_pos := global_position
	var range_sq := cannon_range * cannon_range
	var target_idx: int = -1
	var min_dist_sq: float = range_sq
	
	if "swarm_data" in swarm_simulation and swarm_simulation.swarm_data:
		var sd = swarm_simulation.swarm_data
		var cap: int = sd.capacity
		var alive = sd.alive_mask
		var px = sd.pos_x
		var pz = sd.pos_z
		
		for i in range(cap):
			if not alive[i]:
				continue
			var dx: float = px[i] - my_pos.x
			var dz: float = pz[i] - my_pos.z
			var d_sq := dx * dx + dz * dz
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				target_idx = i
	
	if target_idx >= 0:
		_cannon_timer = 0.0
		# Aim cannon barrel towards target
		var enemy_pos: Vector3 = swarm_simulation.get_unit_position_3d(target_idx)
		if cannon_barrel:
			cannon_barrel.look_at(enemy_pos, Vector3.UP)
		
		# Deal heavy explosive damage to target unit and nearby splash
		swarm_simulation.apply_damage_to_unit(target_idx, cannon_damage)
		FloatingTextManager.spawn_text(
			self,
			enemy_pos + Vector3(0.0, 1.0, 0.0),
			"💥 %d" % int(cannon_damage),
			Color(1.0, 0.6, 0.1)
		)


func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	
	var result := SFECombatEngine.calculate_damage(
		amount,
		SFECombatEngine.DamageType.PHYSICAL,
		structure_armor,
		0,
		SFECombatEngine.StructureType.OTHER,
		false,
		false,
		false,
		0.0,
		current_health,
		SFECombatEngine.TargetTag.STRUCTURE
	)
	
	current_health = maxf(0.0, current_health - result.damage_dealt)
	_update_health_bar()
	
	fortress_damaged.emit(current_health, max_health)
	
	var bus := _get_signal_bus()
	if bus and bus.has_signal("structure_damaged"):
		bus.structure_damaged.emit(self, current_health, max_health)
	
	FloatingTextManager.spawn_text(
		self,
		global_position + Vector3(0.0, 4.0, 0.0),
		"-%d" % int(result.damage_dealt),
		Color(1.0, 0.25, 0.25)
	)
	
	if current_health <= 0.0:
		_destroy_fortress()


func _update_health_bar() -> void:
	if health_bar:
		var ratio := clampf(current_health / max_health, 0.0, 1.0)
		var quad: QuadMesh = health_bar.mesh as QuadMesh
		if quad:
			quad.size = Vector2(4.0 * ratio, 0.28)
			health_bar.position.x = -2.0 * (1.0 - ratio)
		
		var mat: StandardMaterial3D = health_bar.material_override as StandardMaterial3D
		if mat:
			if ratio > 0.5:
				mat.albedo_color = Color(0.15, 0.85, 0.3)
			elif ratio > 0.25:
				mat.albedo_color = Color(0.95, 0.8, 0.15)
			else:
				mat.albedo_color = Color(0.9, 0.15, 0.15)


func _destroy_fortress() -> void:
	fortress_destroyed.emit()
	
	var bus := _get_signal_bus()
	if bus:
		if bus.has_signal("base_destroyed"):
			bus.base_destroyed.emit()
		if bus.has_signal("structure_destroyed"):
			bus.structure_destroyed.emit(self)
	
	FloatingTextManager.spawn_text(
		self,
		global_position + Vector3(0.0, 5.0, 0.0),
		"¡FORTALEZA PLANETARIA DESTRUIDA!",
		Color(1.0, 0.1, 0.1)
	)
	
	queue_free()
