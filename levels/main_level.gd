class_name MainLevel
extends Node3D

## MainLevel - Primary battleground for SFE5 Milestone 6.
## Coordinates global integration across:
## 1. High-Performance Swarm Simulation & MultiMesh batch rendering (SoA flow fields).
## 2. Allied Hero (Jim Raynor / HeroUnit3D) & RTSController selection/orders.
## 3. StarCraft II procedural UI console (SC2HUDRoot, SC2StatPanel, SC2CommandCard).
## 4. Bounty-driven economy & dynamic difficulty scaling (Crossfire Nullification Rule).
## 5. Spatial boss events (SecretBossZone3D, HellsGateZone3D) & 8-pedestals algorithmic puzzle.

const CombatTypes = preload("res://core/combat/combat_types.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const EconomyTypes = preload("res://core/economy/economy_types.gd")
const KillContext = preload("res://core/economy/kill_context.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const SFEDifficultyManager = preload("res://core/economy/sfe_difficulty_manager.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")
const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SecretBossZone3D = preload("res://core/events/secret_boss_zone_3d.gd")
const HellsGateZone3D = preload("res://core/events/hells_gate_zone_3d.gd")
const PedestalPuzzleManager = preload("res://core/puzzles/pedestal_puzzle_manager.gd")
const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const SFEStartModal = preload("res://ui/sfe_start_modal.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")

# Core Systems
@onready var nav_region: NavigationRegion3D = get_node_or_null("NavigationRegion3D")
@onready var rts_controller: RTSController = get_node_or_null("RTSController")
@onready var camera_rig: RTSCamera3D = get_node_or_null("RTSCamera3D")
@onready var wave_manager: WaveManager = get_node_or_null("WaveManager")
@onready var swarm_simulation: SwarmSimulation = get_node_or_null("SwarmSimulation")
@onready var sc2_hud_root: SC2HUDRoot = get_node_or_null("SC2HUDRoot")
@onready var economy_manager: SFEEconomyManager = get_node_or_null("EconomyManager")
@onready var difficulty_manager: SFEDifficultyManager = get_node_or_null("DifficultyManager")
@onready var combat_vfx_pool: Node3D = get_node_or_null("CombatVFXPool")

# Spatial Events & Puzzles
@onready var secret_boss_zone: SecretBossZone3D = get_node_or_null("SpatialEvents/SecretBossZone3D")
@onready var hells_gate_zone: HellsGateZone3D = get_node_or_null("SpatialEvents/HellsGateZone3D")
@onready var pedestal_puzzle: PedestalPuzzleManager = get_node_or_null("SpatialEvents/PedestalPuzzleManager")

# Base Structures
@onready var command_center: CommandCenter = get_node_or_null("NavigationRegion3D/BasePerimeter/CommandCenter")

# UI Elements
@onready var round_label: Label = get_node_or_null("UI/WavePanel/MarginContainer/VBoxContainer/RoundLabel")
@onready var state_label: Label = get_node_or_null("UI/WavePanel/MarginContainer/VBoxContainer/StateLabel")
@onready var cc_health_label: Label = get_node_or_null("UI/WavePanel/MarginContainer/VBoxContainer/CCHealthLabel")
@onready var minerals_label: Label = get_node_or_null("UI/WavePanel/MarginContainer/VBoxContainer/MineralsLabel")
@onready var start_wave_btn: Button = get_node_or_null("UI/WavePanel/MarginContainer/VBoxContainer/StartWaveBtn")
@onready var game_over_panel: PanelContainer = get_node_or_null("UI/GameOverPanel")
@onready var restart_btn: Button = get_node_or_null("UI/GameOverPanel/MarginContainer/VBoxContainer/RestartBtn")

# Active Hero Entity & Modal State
var active_hero: HeroUnit3D = null
var start_modal: SFEStartModal = null
var session_kills: int = 0

# Swarm Combat Throttle
var _swarm_combat_accumulator: float = 0.0


func _ready() -> void:
	# 1. Navigation Mesh & Gate Doors Pre-Bake
	_prepare_navigation_and_gates()

	# 2. Economy & Difficulty Managers Setup
	_setup_economy_and_difficulty()

	# 3. Swarm Simulation & Flow Field Goal/Obstacle Registration
	_setup_swarm_simulation()

	# 4. Hero Spawn & RTS Controller / SC2 HUD Binding
	_setup_hero_and_controls()

	# 5. Spatial Events & Pedestal Puzzle Wiring
	_setup_spatial_events_and_puzzles()

	# 6. Global Signal Listeners
	_setup_event_listeners()

	if game_over_panel:
		game_over_panel.visible = false

	# 7. Milestone 6 Startup Diagnostics
	_log_milestone_6_diagnostics()

	# 8. SFE5 Pre-Mission Modal (Difficulty + Hero Selection + Player Profile)
	_setup_start_modal()


func _process(_delta: float) -> void:
	if sc2_hud_root:
		sc2_hud_root.update_hive_evolution(SFEDifficultyManager.hive_level, SFEDifficultyManager.cadence_timer)


func _setup_start_modal() -> void:
	# Initial Top Bar Sync from Bank
	var bank: Dictionary = BankManager.load_bank()
	if sc2_hud_root:
		sc2_hud_root.update_veterancy(bank.get("veterancy_level", 1))
		sc2_hud_root.update_difficulty(SFEDifficultyManager.get_difficulty_name(), SFEDifficultyManager.get_difficulty())
		if economy_manager:
			sc2_hud_root.update_minerals(economy_manager.current_minerals)

	start_modal = SFEStartModal.new()
	start_modal.name = "SFEStartModal"
	add_child(start_modal)
	start_modal.deployment_confirmed.connect(_on_deployment_confirmed)


func _on_deployment_confirmed(selected_hero: HeroData, diff_tier: int, is_random: bool) -> void:
	# 1. Apply difficulty scaling
	if difficulty_manager:
		difficulty_manager.set_difficulty(diff_tier)
	elif SFEDifficultyManager.instance:
		SFEDifficultyManager.set_difficulty(diff_tier)

	# 2. Apply Random Hero Bonus (+50 minerals)
	if is_random and economy_manager:
		economy_manager.add_minerals(50, "Random Hero Deployment Bonus")

	# 3. Bind Selected Hero Data & Visuals
	if selected_hero and active_hero:
		active_hero.hero_data = selected_hero
		active_hero._bind_hero_data()
		active_hero.apply_archetype_visuals(selected_hero)
		if rts_controller:
			rts_controller.clear_selection()
			rts_controller.select_unit(active_hero)
			SignalBus.units_selected.emit([active_hero])

	# 4. Update SC2 Top Bar
	if sc2_hud_root:
		sc2_hud_root.update_difficulty(SFEDifficultyManager.get_difficulty_name(), diff_tier)
		if economy_manager:
			sc2_hud_root.update_minerals(economy_manager.current_minerals)

	start_modal = null


func _prepare_navigation_and_gates() -> void:
	var gates: Array[Node] = get_tree().get_nodes_in_group("gates")
	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.door_collision:
				gate.door_collision.disabled = true

	if nav_region:
		if not nav_region.navigation_mesh:
			var nav_mesh: NavigationMesh = NavigationMesh.new()
			nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
			nav_mesh.agent_radius = 0.5
			nav_mesh.agent_height = 1.75
			nav_mesh.agent_max_climb = 0.5
			nav_mesh.cell_size = 0.25
			nav_mesh.cell_height = 0.25
			nav_region.navigation_mesh = nav_mesh
		else:
			nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

		nav_region.bake_navigation_mesh(false)

	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.initial_state == GateStructure.GateState.CLOSED:
				gate.close_gate(false)
			else:
				gate.open_gate(false)


func _setup_economy_and_difficulty() -> void:
	if not economy_manager:
		economy_manager = SFEEconomyManager.new()
		economy_manager.name = "EconomyManager"
		add_child(economy_manager)

	if not difficulty_manager:
		difficulty_manager = SFEDifficultyManager.new()
		difficulty_manager.name = "DifficultyManager"
		add_child(difficulty_manager)

	if economy_manager:
		if not economy_manager.minerals_changed.is_connected(_on_minerals_changed):
			economy_manager.minerals_changed.connect(_on_minerals_changed)
		_update_minerals_ui(economy_manager.current_minerals)


func _setup_swarm_simulation() -> void:
	if not swarm_simulation:
		swarm_simulation = SwarmSimulation.new()
		swarm_simulation.name = "SwarmSimulation"
		swarm_simulation.max_units = 2048
		swarm_simulation.map_bounds_min = Vector2(-42.0, -42.0)
		swarm_simulation.map_bounds_max = Vector2(42.0, 42.0)
		add_child(swarm_simulation)

	# Ensure WaveManager is linked to SwarmSimulation for mass horde spawning
	if wave_manager and not wave_manager.swarm_simulation:
		wave_manager.swarm_simulation = swarm_simulation

	# Register Command Center as primary goal in SwarmSimulation
	var cc_pos := Vector3(0.0, 0.0, 14.0)
	if command_center:
		cc_pos = command_center.global_position
	elif not get_tree().get_nodes_in_group("command_centers").is_empty():
		var cc_node: Node3D = get_tree().get_nodes_in_group("command_centers")[0] as Node3D
		if cc_node:
			cc_pos = cc_node.global_position
	
	swarm_simulation.register_goal(cc_pos)

	# Register perimeter structures (WallSegment, GateStructure, Bunkers) as dynamic obstacles
	_register_all_perimeter_obstacles()


func _register_all_perimeter_obstacles() -> void:
	if not swarm_simulation:
		return

	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")
	for node in structures:
		if not (node is Node3D):
			continue
		var s: Node3D = node as Node3D

		if s is WallSegment:
			var local_half := Vector3(2.0, 1.6, 0.6)
			var basis := s.global_transform.basis
			var world_half_x: float = absf(basis.x.x * local_half.x) + absf(basis.z.x * local_half.z)
			var world_half_z: float = absf(basis.x.z * local_half.x) + absf(basis.z.z * local_half.z)
			var half_size := Vector3(world_half_x + 0.15, 1.6, world_half_z + 0.15)
			var is_front_wall: bool = (s.global_position.z <= 5.0)
			var wall_cost: int = 60 if is_front_wall else 255
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true, wall_cost)
		elif s is GateStructure:
			var gate: GateStructure = s as GateStructure
			var half_size: Vector3 = Vector3(3.1, 1.6, 0.8)
			var is_closed: bool = (gate.current_state == GateStructure.GateState.CLOSED)
			var gate_cost: int = 20 if is_closed else 1
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, is_closed, gate_cost)
		elif s is CommandCenter:
			var half_size: Vector3 = Vector3(4.0, 2.0, 4.0)
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true)
		elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
			var half_size: Vector3 = Vector3(2.5, 1.5, 2.5)
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true, 80)


func _setup_hero_and_controls() -> void:
	# Locate existing hero in scene or instantiate Jim Raynor
	var heroes: Array[Node] = get_tree().get_nodes_in_group("heroes")
	if not heroes.is_empty() and heroes[0] is HeroUnit3D:
		active_hero = heroes[0] as HeroUnit3D
	else:
		active_hero = HeroUnit3D.new()
		active_hero.name = "HeroRaynor"
		var allies_node: Node = get_node_or_null("Allies")
		if allies_node:
			allies_node.add_child(active_hero)
		else:
			add_child(active_hero)

	# Ensure Jim Raynor RPG data is initialized
	if active_hero.hero_data == null or active_hero.hero_data.archetype_id != &"marine":
		var raynor_data = HeroSelector.select_hero_manual(&"raynor")
		if raynor_data:
			active_hero.hero_data = raynor_data
			active_hero._bind_hero_data()

	# Position Hero at the base rally point
	var rally_point: Node3D = get_node_or_null("RallyPoint") as Node3D
	if rally_point:
		active_hero.global_position = rally_point.global_position
	elif command_center:
		active_hero.global_position = command_center.global_position + Vector3(0.0, 0.0, -4.0)
	else:
		active_hero.global_position = Vector3(0.0, 0.0, 10.0)

	# Listen to hero skill casts for area of effect damage attribution
	if not active_hero.skill_cast.is_connected(_on_hero_skill_cast):
		active_hero.skill_cast.connect(_on_hero_skill_cast)

	# Instantiate SC2HUDRoot if not already in scene tree
	if not sc2_hud_root:
		sc2_hud_root = SC2HUDRoot.new()
		sc2_hud_root.name = "SC2HUDRoot"
		add_child(sc2_hud_root)

	# Connect hero to RTSController as the initially active selected unit
	if rts_controller and is_instance_valid(active_hero):
		rts_controller.clear_selection()
		rts_controller.select_unit(active_hero)
		SignalBus.units_selected.emit([active_hero])


func _setup_spatial_events_and_puzzles() -> void:
	if secret_boss_zone:
		if not secret_boss_zone.secret_boss_invoked.is_connected(_on_secret_boss_invoked):
			secret_boss_zone.secret_boss_invoked.connect(_on_secret_boss_invoked)

	if hells_gate_zone:
		if not hells_gate_zone.hells_gate_opened.is_connected(_on_hells_gate_opened):
			hells_gate_zone.hells_gate_opened.connect(_on_hells_gate_opened)

	if pedestal_puzzle:
		if not pedestal_puzzle.puzzle_solved.is_connected(_on_pedestal_puzzle_solved):
			pedestal_puzzle.puzzle_solved.connect(_on_pedestal_puzzle_solved)


func _setup_event_listeners() -> void:
	if not SignalBus.structure_destroyed.is_connected(_on_structure_destroyed):
		SignalBus.structure_destroyed.connect(_on_structure_destroyed)
	if not SignalBus.structure_damaged.is_connected(_on_structure_damaged):
		SignalBus.structure_damaged.connect(_on_structure_damaged)
	if not SignalBus.gate_state_changed.is_connected(_on_gate_state_changed):
		SignalBus.gate_state_changed.connect(_on_gate_state_changed)
	if not SignalBus.wave_started.is_connected(_on_wave_started):
		SignalBus.wave_started.connect(_on_wave_started)
	if not SignalBus.wave_completed.is_connected(_on_wave_completed):
		SignalBus.wave_completed.connect(_on_wave_completed)
	if not SignalBus.wave_enemy_count_changed.is_connected(_on_wave_enemy_count_changed):
		SignalBus.wave_enemy_count_changed.connect(_on_wave_enemy_count_changed)
	if not SignalBus.enemy_died.is_connected(_on_enemy_died):
		SignalBus.enemy_died.connect(_on_enemy_died)
	if not SignalBus.base_destroyed.is_connected(_on_base_destroyed):
		SignalBus.base_destroyed.connect(_on_base_destroyed)

	if start_wave_btn and not start_wave_btn.pressed.is_connected(_on_start_wave_pressed):
		start_wave_btn.pressed.connect(_on_start_wave_pressed)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_pressed):
		restart_btn.pressed.connect(_on_restart_pressed)


func _physics_process(delta: float) -> void:
	_swarm_combat_accumulator += delta
	# Process swarm combat checks every ~100ms for high performance
	if _swarm_combat_accumulator >= 0.10:
		_process_swarm_combat(_swarm_combat_accumulator)
		_swarm_combat_accumulator = 0.0


## High-performance combat loop evaluating swarm attack strikes and allied defense responses.
func _process_swarm_combat(dt: float) -> void:
	if not swarm_simulation or not swarm_simulation.swarm_data:
		return

	var sdata = swarm_simulation.swarm_data
	if sdata.active_count == 0:
		return

	var cap: int = sdata.capacity
	var alive: PackedByteArray = sdata.alive_mask
	var px: PackedFloat32Array = sdata.pos_x
	var pz: PackedFloat32Array = sdata.pos_z
	var atk_dmg: PackedFloat32Array = sdata.attack_damage
	var atk_rng: PackedFloat32Array = sdata.attack_range
	var atk_cd: PackedFloat32Array = sdata.attack_cooldown
	var atk_tmr: PackedFloat32Array = sdata.attack_timer

	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")

	# 1. Swarm Units Melee Assault on Perimeter & Base
	var active_limit: int = sdata.active_count
	var processed: int = 0

	for i in range(cap):
		if alive[i] == 0:
			continue

		atk_tmr[i] = maxf(0.0, atk_tmr[i] - dt)
		if atk_tmr[i] <= 0.0:
			var unit_pos := Vector3(px[i], 0.0, pz[i])
			var range_val: float = atk_rng[i]
			var hit_target: Node3D = null
			var hit_struct_type: int = CombatTypes.StructureType.NONE

			# Check structures
			for node in structures:
				if not is_instance_valid(node) or not (node is Node3D):
					continue
				var s: Node3D = node as Node3D
				var struct_radius: float = 2.0
				if s is CommandCenter:
					struct_radius = 4.0
				elif s is GateStructure:
					struct_radius = 2.5
				elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
					struct_radius = 2.5

				if unit_pos.distance_to(s.global_position) <= (range_val + struct_radius):
					hit_target = s
					if s is WallSegment:
						hit_struct_type = CombatTypes.StructureType.WALL_REINFORCED
					elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
						hit_struct_type = CombatTypes.StructureType.BUNKER
					break

			# Check allies if no structure hit
			if not hit_target:
				for node in allies:
					if not is_instance_valid(node) or not (node is Node3D):
						continue
					var a: Node3D = node as Node3D
					if unit_pos.distance_to(a.global_position) <= (range_val + 0.6):
						hit_target = a
						break

			# Execute physical attack strike through SFECombatEngine
			if hit_target:
				atk_tmr[i] = atk_cd[i]
				var raw_dmg: float = atk_dmg[i]
				var res = SFECombatEngine.calculate_damage(
					raw_dmg,
					CombatTypes.DamageType.PHYSICAL,
					0.0,
					0,
					hit_struct_type,
					hit_target is HeroUnit3D
				)
				if hit_target.has_method("take_damage_context"):
					hit_target.take_damage_context(raw_dmg, CombatTypes.DamageType.PHYSICAL, false, 0)
				elif hit_target.has_method("take_damage"):
					hit_target.take_damage(res.damage_dealt)

		processed += 1
		if processed >= active_limit:
			break

	# 2. Allied Units & Hero Firing on Swarm
	for node in allies:
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var ally: Node3D = node as Node3D
		var ally_range: float = 8.5
		var ally_dmg: float = 12.0
		if ally is HeroUnit3D:
			var h: HeroUnit3D = ally as HeroUnit3D
			ally_range = h.attack_range
			ally_dmg = h.hero_data.weapon_damage if h.hero_data else h.attack_damage
		elif "attack_range" in ally and "attack_damage" in ally:
			ally_range = ally.attack_range
			ally_dmg = ally.attack_damage

		# Find nearest swarm unit using spatial hash
		if swarm_simulation.spatial_hash:
			var center_2d := Vector2(ally.global_position.x, ally.global_position.z)
			var candidates = swarm_simulation.spatial_hash.query_radius(center_2d, ally_range, sdata)
			if candidates.size() > 0:
				var target_idx: int = candidates[0]
				var target_pos := Vector3(sdata.pos_x[target_idx], 0.35, sdata.pos_z[target_idx])
				if combat_vfx_pool:
					combat_vfx_pool.spawn_tracer(ally.global_position + Vector3(0.0, 1.1, 0.0), target_pos)
				var killed: bool = swarm_simulation.apply_damage_to_unit(target_idx, ally_dmg)
				if killed:
					if combat_vfx_pool:
						combat_vfx_pool.spawn_acid_burst(target_pos)
					var bounty: int = award_kill_bounty(null, ally, 5, EconomyTypes.Faction.ALLIED, CombatTypes.DamageType.PHYSICAL)
					FloatingTextManager.spawn_text(self, target_pos, "+%d Minerals" % bounty, Color(0.2, 0.95, 1.0))
					if active_hero:
						active_hero.gain_experience(15)
					session_kills += 1
					if wave_manager:
						wave_manager.on_swarm_unit_died(5)

	# 3. Fortified Bunkers Automated Defense Firing
	for s_node in structures:
		if not is_instance_valid(s_node) or not (s_node is Node3D):
			continue
		if s_node.name.to_lower().contains("bunker") or s_node.is_in_group("bunkers"):
			var b_node: Node3D = s_node as Node3D
			if swarm_simulation.spatial_hash:
				var b_center := Vector2(b_node.global_position.x, b_node.global_position.z)
				var b_candidates = swarm_simulation.spatial_hash.query_radius(b_center, 9.5, sdata)
				if b_candidates.size() > 0:
					var b_target_idx: int = b_candidates[0]
					var b_target_pos := Vector3(sdata.pos_x[b_target_idx], 0.35, sdata.pos_z[b_target_idx])
					if combat_vfx_pool:
						combat_vfx_pool.spawn_tracer(b_node.global_position + Vector3(0.0, 1.8, 0.0), b_target_pos)
					var b_killed: bool = swarm_simulation.apply_damage_to_unit(b_target_idx, 16.0)
					if b_killed:
						if combat_vfx_pool:
							combat_vfx_pool.spawn_acid_burst(b_target_pos)
						var b_bounty: int = award_kill_bounty(null, b_node, 5, EconomyTypes.Faction.ALLIED, CombatTypes.DamageType.PHYSICAL)
						FloatingTextManager.spawn_text(self, b_target_pos, "+%d Minerals" % b_bounty, Color(0.2, 0.95, 1.0))
						if active_hero:
							active_hero.gain_experience(10)
						session_kills += 1
						if wave_manager:
							wave_manager.on_swarm_unit_died(5)


## Awards mineral kill bounty honoring the strict Crossfire Nullification Rule (Requirement R3).
func award_kill_bounty(
	victim: Object,
	killer: Object,
	base_bounty: int,
	killer_faction: int = EconomyTypes.Faction.ALLIED,
	lethal_damage_type: int = 0
) -> int:
	var ctx := KillContext.new(victim, killer, killer_faction, base_bounty, lethal_damage_type)
	if economy_manager:
		return economy_manager.process_kill(ctx)
	return 0


func _on_hero_skill_cast(skill: Variant, target: Variant) -> void:
	if not swarm_simulation or not swarm_simulation.spatial_hash:
		return
	if skill == null:
		return

	var radius: float = skill.area_radius if "area_radius" in skill else 0.0
	var power: float = skill.base_power if "base_power" in skill else 0.0
	var dmg_type: int = skill.damage_type if "damage_type" in skill else CombatTypes.DamageType.SPELL

	if radius <= 0.0 or power <= 0.0:
		return

	var target_pos: Vector3 = target if target is Vector3 else (active_hero.global_position if active_hero else Vector3.ZERO)
	var center_2d := Vector2(target_pos.x, target_pos.z)
	var candidates = swarm_simulation.spatial_hash.query_radius(center_2d, radius, swarm_simulation.swarm_data)

	for unit_idx in candidates:
		var killed: bool = swarm_simulation.apply_damage_to_unit(unit_idx, power)
		if killed:
			var victim_pos := Vector3(
				swarm_simulation.swarm_data.pos_x[unit_idx],
				0.35,
				swarm_simulation.swarm_data.pos_z[unit_idx]
			)
			if combat_vfx_pool:
				combat_vfx_pool.spawn_acid_burst(victim_pos)
			var bounty: int = award_kill_bounty(null, active_hero, 5, EconomyTypes.Faction.ALLIED, dmg_type)
			FloatingTextManager.spawn_text(self, victim_pos, "+%d Minerals" % bounty, Color(0.2, 0.95, 1.0))
			if active_hero:
				active_hero.gain_experience(15)
			session_kills += 1
			if wave_manager:
				wave_manager.on_swarm_unit_died(5)


func _on_secret_boss_invoked(boss_scene: PackedScene, spawn_transform: Transform3D) -> void:
	if boss_scene:
		var boss: Node3D = boss_scene.instantiate() as Node3D
		add_child(boss)
		boss.global_transform = spawn_transform
		if state_label:
			state_label.text = "¡ALERTA! ¡OMEGA ULTRALISK INVOCADO!"
			state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))


func _on_hells_gate_opened(_nydus_boss: Node3D) -> void:
	if state_label:
		state_label.text = "¡ALERTA! ¡HELL'S GATE NYDUS DESATADO!"
		state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.8))


func _on_pedestal_puzzle_solved(reward_data: Dictionary) -> void:
	var bonus_minerals: int = reward_data.get("minerals", 2500)
	if economy_manager:
		economy_manager.add_minerals(bonus_minerals, "Pedestal Puzzle Solved")
	if state_label:
		state_label.text = "¡PUZZLE DE PEDESTALES RESUELTO!"
		state_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))


func _on_gate_state_changed(gate: Node, is_open: bool) -> void:
	if swarm_simulation and is_instance_valid(gate) and gate is Node3D:
		var g: Node3D = gate as Node3D
		var half_size: Vector3 = Vector3(3.1, 1.6, 0.8)
		var gate_cost: int = 1 if is_open else 20
		swarm_simulation.register_obstacle_aabb(g, g.global_position - half_size, g.global_position + half_size, not is_open, gate_cost)


func _on_structure_destroyed(structure: Node) -> void:
	if structure is CommandCenter:
		SignalBus.base_destroyed.emit()
		return

	if swarm_simulation and is_instance_valid(structure):
		swarm_simulation.unregister_obstacle(structure)

	# If a wall segment or gate is destroyed, re-bake navmesh for breach routing
	if (structure is WallSegment or structure is GateStructure) and nav_region:
		nav_region.bake_navigation_mesh(true)


func _on_structure_damaged(structure: Node, current_hp: float, max_hp: float) -> void:
	if structure is CommandCenter:
		if cc_health_label:
			cc_health_label.text = "Integridad Command Center: %d / %d" % [int(current_hp), int(max_hp)]
			if current_hp <= max_hp * 0.3:
				cc_health_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			elif current_hp <= max_hp * 0.6:
				cc_health_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		if sc2_hud_root:
			sc2_hud_root.update_command_center_hp(current_hp, max_hp)


func _on_wave_started(wave_number: int, total_enemies: int) -> void:
	if round_label:
		round_label.text = "Ronda Actual: %d" % wave_number
	if state_label:
		state_label.text = "¡OLEADA EN CURSO! (Hostiles: %d)" % total_enemies
		state_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if start_wave_btn:
		start_wave_btn.visible = false
	if sc2_hud_root:
		sc2_hud_root.update_wave_status(wave_number, total_enemies, true)


func _on_wave_enemy_count_changed(alive_count: int) -> void:
	if state_label and wave_manager and wave_manager.is_wave_in_progress:
		state_label.text = "¡OLEADA EN CURSO! (Hostiles: %d)" % alive_count
	if sc2_hud_root:
		var cur_w: int = wave_manager.current_wave if wave_manager else 1
		sc2_hud_root.update_wave_status(cur_w, alive_count, true)


func _on_wave_completed(wave_number: int) -> void:
	if round_label:
		round_label.text = "Ronda %d Completada" % wave_number
	if state_label:
		state_label.text = "Estado: FASE TÁCTICA"
		state_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	if start_wave_btn:
		start_wave_btn.visible = true
		start_wave_btn.text = "▶ INICIAR RONDA %d" % (wave_number + 1)
	if sc2_hud_root:
		sc2_hud_root.update_wave_status(wave_number, 0, false)
	_save_bank_progress(false)


func _on_enemy_died(enemy: Node, reward: int) -> void:
	var killer_faction: int = EconomyTypes.Faction.ALLIED
	var killer_node: Object = active_hero
	var enemy_pos := Vector3.ZERO
	if is_instance_valid(enemy):
		if enemy.has_meta("killer_faction"):
			killer_faction = enemy.get_meta("killer_faction")
		if enemy.has_meta("killer"):
			killer_node = enemy.get_meta("killer")
		if enemy is Node3D:
			enemy_pos = (enemy as Node3D).global_position
			if combat_vfx_pool:
				combat_vfx_pool.spawn_acid_burst(enemy_pos)

	var bounty: int = award_kill_bounty(enemy, killer_node, reward, killer_faction)
	if bounty > 0 and enemy_pos != Vector3.ZERO:
		FloatingTextManager.spawn_text(self, enemy_pos, "+%d Minerals" % bounty, Color(0.2, 0.95, 1.0))
	if active_hero:
		active_hero.gain_experience(reward * 3)
	session_kills += 1


func _on_minerals_changed(new_amount: int, _delta: int, _reason: String) -> void:
	_update_minerals_ui(new_amount)
	if sc2_hud_root:
		sc2_hud_root.update_minerals(new_amount)


func _update_minerals_ui(amount: int) -> void:
	if minerals_label:
		minerals_label.text = "Minerales: %d" % amount


func _on_start_wave_pressed() -> void:
	if wave_manager:
		wave_manager.start_next_wave()


func _on_base_destroyed() -> void:
	_save_bank_progress(true)
	if game_over_panel:
		game_over_panel.visible = true


func _save_bank_progress(is_game_over: bool) -> void:
	var bank: Dictionary = BankManager.load_bank()
	var prev_kills: int = bank.get("total_kills", 0)
	var new_total_kills: int = prev_kills + session_kills
	session_kills = 0
	bank["total_kills"] = new_total_kills
	var new_vet: int = maxi(1, 1 + int(new_total_kills / 100))
	bank["veterancy_level"] = new_vet

	if is_game_over:
		bank["losses"] = bank.get("losses", 0) + 1
	else:
		bank["highest_wave"] = maxi(bank.get("highest_wave", 0), wave_manager.current_wave if wave_manager else 1)
		bank["wins"] = bank.get("wins", 0) + 1

	BankManager.save_bank(bank)
	if sc2_hud_root:
		sc2_hud_root.update_veterancy(new_vet)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _log_milestone_6_diagnostics() -> void:
	print("\n=============================================================")
	print("=== SFE5 MILESTONE 6: GLOBAL INTEGRATION DIAGNOSTICS ===")
	print("=============================================================")
	if swarm_simulation and swarm_simulation.flow_field:
		var goals_count: int = swarm_simulation.flow_field.goals.size()
		var obs_count: int = swarm_simulation.flow_field.registered_obstacles.size()
		print("  [M6 INTEGRATION] SwarmSimulation: ACTIVE (Capacity: %d, Goals: %d, Dynamic Obstacles: %d)" % [
			swarm_simulation.max_units, goals_count, obs_count
		])
	else:
		push_warning("SwarmSimulation or FlowField not initialized!")

	if wave_manager:
		var is_linked: bool = (wave_manager.swarm_simulation == swarm_simulation)
		print("  [M6 INTEGRATION] WaveManager: ACTIVE (Linked to SwarmSimulation: %s)" % str(is_linked))

	if active_hero and active_hero.hero_data:
		print("  [M6 INTEGRATION] Allied Hero: ACTIVE (Archetype: '%s', Name: '%s', HP: %.0f, Damage: %.1f)" % [
			active_hero.hero_data.archetype_id,
			active_hero.hero_data.hero_name,
			active_hero.hero_data.max_hp,
			active_hero.hero_data.weapon_damage
		])

	if rts_controller:
		var has_hero: bool = rts_controller.selected_units.has(active_hero)
		print("  [M6 INTEGRATION] RTSController: ACTIVE (Selected Units: %d, Hero Selected: %s)" % [
			rts_controller.selected_units.size(), str(has_hero)
		])

	if sc2_hud_root:
		var stat_bound: bool = (sc2_hud_root.stat_panel and sc2_hud_root.stat_panel.bound_unit == active_hero)
		var cmd_slots: int = sc2_hud_root.command_card.slot_buttons.size() if sc2_hud_root.command_card else 0
		print("  [M6 INTEGRATION] SC2 HUD Console: ACTIVE (StatPanel Bound to Hero: %s, CommandCard Slots: %d)" % [
			str(stat_bound), cmd_slots
		])

	if economy_manager and difficulty_manager:
		print("  [M6 INTEGRATION] Economy & Difficulty: ACTIVE (Wallet: %d minerals, Difficulty Tier: %s [%d])" % [
			economy_manager.current_minerals,
			difficulty_manager.get_difficulty_name(),
			difficulty_manager.get_difficulty()
		])

	var events_ok: bool = (secret_boss_zone != null and hells_gate_zone != null and pedestal_puzzle != null)
	var ped_count: int = pedestal_puzzle.pedestals.size() if pedestal_puzzle else 0
	print("  [M6 INTEGRATION] Spatial Events & Puzzles: ACTIVE (Events Found: %s, Pedestals: %d)" % [
		str(events_ok), ped_count
	])

	if combat_vfx_pool:
		print("  [M4 INTEGRATION] CombatVFXPool: ACTIVE (Tracers: %d, Acid Bursts: %d)" % [
			combat_vfx_pool.get_tracer_pool_size(),
			combat_vfx_pool.get_acid_pool_size()
		])
	print("=============================================================\n")
