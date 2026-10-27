class_name SpawnerArena
extends Node3D

## SpawnerArena - Lightweight test arena for SpawnerChain and horde combat (Task 3.15).
## Allows instant validation and headless testing of 3 chained spawners, budget clamping,
## and colored enemy mutation without loading heavy level assets.

const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const SpawnerChain = preload("res://core/spawners/spawner_chain.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")
const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const PlanetaryFortress = preload("res://entities/structures/planetary_fortress.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const SFEGameOverModal = preload("res://ui/sfe_game_over_modal.gd")

var budget_manager: EnemyBudgetManager
var spawner_chain: SpawnerChain
var swarm_sim: SwarmSimulation
var fortress: PlanetaryFortress
var hero: HeroUnit3D

var spawner_a: SpawnerNode
var spawner_b: SpawnerNode
var spawner_c: SpawnerNode

var match_timer: float = 0.0
var total_kills: int = 0
var is_game_over: bool = false


func _ready() -> void:
	_setup_arena_environment()
	_setup_simulation_and_budget()
	_setup_fortress_and_hero()
	_setup_spawner_chain()


func _setup_arena_environment() -> void:
	# Ground plane (60x60m)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(col)
	
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.16)
	mat.roughness = 0.8
	mi.material_override = mat
	ground.add_child(mi)
	add_child(ground)
	
	# Light & Sun
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)


func _setup_simulation_and_budget() -> void:
	swarm_sim = SwarmSimulation.new()
	swarm_sim.name = "SwarmSimulation"
	swarm_sim.setup_simulation(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 1024)
	add_child(swarm_sim)
	
	budget_manager = EnemyBudgetManager.new(300)
	budget_manager.set_simulation(swarm_sim)


func _setup_fortress_and_hero() -> void:
	# Planetary Fortress at base (bottom-left corner: -18, 0, -18)
	fortress = PlanetaryFortress.new()
	fortress.name = "PlanetaryFortress"
	fortress.position = Vector3(-18.0, 0.0, -18.0)
	fortress.set_simulation(swarm_sim)
	add_child(fortress)
	
	swarm_sim.register_goal(fortress.global_position)
	fortress.fortress_destroyed.connect(_on_defeat)
	
	# Hero near fortress
	hero = HeroUnit3D.new()
	hero.name = "ArenaHero"
	hero.position = Vector3(-12.0, 0.0, -14.0)
	add_child(hero)


func _setup_spawner_chain() -> void:
	spawner_chain = SpawnerChain.new()
	spawner_chain.name = "SpawnerChain"
	spawner_chain.set_simulation(swarm_sim)
	add_child(spawner_chain)
	
	# 1. Spawner A: Zergling Spawner (ACTIVE from start)
	spawner_a = SpawnerNode.new()
	spawner_a.name = "Spawner_A_Zergling"
	spawner_a.spawner_id = &"spawner_01"
	spawner_a.spawner_name = "Nido Zergling"
	spawner_a.family = "zergling"
	spawner_a.archetype_id = 0
	spawner_a.max_health = 1200.0
	spawner_a.current_health = 1200.0
	spawner_a.group_size = 4
	spawner_a.cycle_seconds = 20.0
	spawner_a.budget_manager = budget_manager
	spawner_a.swarm_simulation = swarm_sim
	spawner_a.position = Vector3(10.0, 0.0, -5.0)
	add_child(spawner_a)
	spawner_chain.register_spawner(spawner_a, &"")
	
	# 2. Spawner B: Roach Warren (LOCKED until Spawner A dies)
	spawner_b = SpawnerNode.new()
	spawner_b.name = "Spawner_B_Roach"
	spawner_b.spawner_id = &"spawner_02"
	spawner_b.spawner_name = "Madriguera Roach"
	spawner_b.family = "roach"
	spawner_b.archetype_id = 1
	spawner_b.max_health = 1800.0
	spawner_b.current_health = 1800.0
	spawner_b.group_size = 3
	spawner_b.cycle_seconds = 20.0
	spawner_b.budget_manager = budget_manager
	spawner_b.swarm_simulation = swarm_sim
	spawner_b.position = Vector3(5.0, 0.0, 15.0)
	add_child(spawner_b)
	spawner_chain.register_spawner(spawner_b, &"spawner_01")
	
	# 3. Spawner C: Hydra Den (LOCKED until Spawner B dies)
	spawner_c = SpawnerNode.new()
	spawner_c.name = "Spawner_C_Hydra"
	spawner_c.spawner_id = &"spawner_03"
	spawner_c.spawner_name = "Guarida Hidralisco"
	spawner_c.family = "hydra"
	spawner_c.archetype_id = 3
	spawner_c.max_health = 2400.0
	spawner_c.current_health = 2400.0
	spawner_c.group_size = 3
	spawner_c.cycle_seconds = 20.0
	spawner_c.budget_manager = budget_manager
	spawner_c.swarm_simulation = swarm_sim
	spawner_c.position = Vector3(18.0, 0.0, 18.0)
	add_child(spawner_c)
	spawner_chain.register_spawner(spawner_c, &"spawner_02")
	
	spawner_chain.all_spawners_destroyed.connect(_on_all_spawners_destroyed)


func _physics_process(delta: float) -> void:
	if not is_game_over:
		match_timer += delta


func _on_all_spawners_destroyed() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	var modal := SFEGameOverModal.new()
	modal.setup(
		true,
		match_timer,
		total_kills,
		15000,
		3,
		3,
		"Normal"
	)
	add_child(modal)


func _on_defeat() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	var modal := SFEGameOverModal.new()
	modal.setup(
		false,
		match_timer,
		total_kills,
		5000,
		spawner_chain.get_total_spawner_count() - spawner_chain.get_remaining_spawner_count(),
		spawner_chain.get_total_spawner_count(),
		"Normal"
	)
	add_child(modal)
