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
const BossHealthBarUI = preload("res://ui/boss_health_bar_ui.gd")
const IncomeParams = preload("res://core/economy/income_params.gd")
const IncomeFormula = preload("res://core/economy/income_formula.gd")
const SpawnerNode = preload("res://core/spawners/spawner_node.gd")
const SpawnerChain = preload("res://core/spawners/spawner_chain.gd")
const EnemyBudgetManager = preload("res://core/spawners/enemy_budget_manager.gd")
const MapSeed = preload("res://core/map/map_seed.gd")
const MapGenerator = preload("res://core/map/map_generator.gd")
const SFEGameOverModal = preload("res://ui/sfe_game_over_modal.gd")
const PlanetaryFortress = preload("res://entities/structures/planetary_fortress.gd")
const PlayerConsole = preload("res://ui/player_console.gd")
const TimedEventSchedule = preload("res://core/events/timed_event_schedule.gd")
const DropPodManager = preload("res://core/events/drop_pod_manager.gd")
const NydusCraterManager = preload("res://core/events/nydus_crater_manager.gd")
const ScheduledAttackManager = preload("res://core/events/scheduled_attack_manager.gd")

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
var boss_health_bar_ui: BossHealthBarUI = null

# Active Hero Entity & Modal State
var active_hero: HeroUnit3D = null
var start_modal: SFEStartModal = null
var session_kills: int = 0

# Swarm Combat Throttle
var _swarm_combat_accumulator: float = 0.0

# SFE5 F3 Debug Telemetry Overlay
var debug_telemetry_panel: PanelContainer = null
var debug_telemetry_label: Label = null

# SFE5 Spawner Chain & Procedural Map (Fase 3)
var budget_manager: EnemyBudgetManager = null
var map_generator: MapGenerator = null
var spawner_chain: SpawnerChain = null
var match_timer: float = 0.0
var spawners_destroyed_count: int = 0
var is_game_over: bool = false

# SFE5 Player RPG Console (Fase 4)
var player_console: PlayerConsole = null

# SFE5 Timed Events & External Pressure (Fase 8)
var timed_schedule: TimedEventSchedule = null
var drop_pod_manager: DropPodManager = null
var nydus_crater_manager: NydusCraterManager = null
var scheduled_attack_manager: ScheduledAttackManager = null


func _ready() -> void:
	# 1. Navigation Mesh & Gate Doors Pre-Bake
	_prepare_navigation_and_gates()

	# 2. Economy & Difficulty Managers Setup
	_setup_economy_and_difficulty()

	# 3. Swarm Simulation & Flow Field Goal/Obstacle Registration
	_setup_swarm_simulation()

	# 3b. SFE5 Spawner Chain & Procedural Map (Task 3.12)
	_setup_spawner_network()

	# 4. Hero Spawn & RTS Controller / SC2 HUD Binding
	_setup_hero_and_controls()

	# 5. Spatial Events & Pedestal Puzzle Wiring
	_setup_spatial_events_and_puzzles()

	# 6. Global Signal Listeners
	_setup_event_listeners()

	# 7. Boss Health Bar UI & Spawning Setup
	_setup_boss_health_bar_ui()

	if game_over_panel:
		game_over_panel.visible = false

	# 8. Milestone 6 Startup Diagnostics
	_log_milestone_6_diagnostics()

	# 9. SFE5 Pre-Mission Modal (Difficulty + Hero Selection + Player Profile)
	_setup_start_modal()

	# 10. SFE5 Player RPG Console (Alt+C)
	_setup_player_console()

	# 11. SFE5 Timed Events & Scheduled Attacks (Fase 8)
	_setup_timed_events_and_pressure()


func _setup_player_console() -> void:
	player_console = PlayerConsole.new()
	player_console.name = "PlayerConsole"
	add_child(player_console)
	if active_hero:
		player_console.target_unit = active_hero


func _setup_timed_events_and_pressure() -> void:
	var seed_val: int = 123456
	var sess := _get_game_session()
	if sess and "match_seed" in sess:
		seed_val = int(sess.match_seed)

	timed_schedule = TimedEventSchedule.new(seed_val)
	drop_pod_manager = DropPodManager.new()
	nydus_crater_manager = NydusCraterManager.new(timed_schedule)
	scheduled_attack_manager = ScheduledAttackManager.new(timed_schedule)

	# Wire internal signals to SignalBus for decoupled presentation
	timed_schedule.drop_pod_due.connect(_on_drop_pod_due)
	scheduled_attack_manager.attack_warning_received.connect(_on_scheduled_attack_warning)
	scheduled_attack_manager.wave_attack_dispatched.connect(_on_scheduled_attack_dispatched)
	nydus_crater_manager.crater_tremor_started.connect(_on_nydus_tremor_started)


func _process(delta: float) -> void:
	if not is_game_over:
		match_timer += delta
		_process_timed_events(delta)
	if sc2_hud_root:
		sc2_hud_root.update_hive_evolution(SFEDifficultyManager.hive_level, SFEDifficultyManager.cadence_timer)
	if debug_telemetry_panel and debug_telemetry_panel.visible:
		_update_debug_telemetry()


func _process_timed_events(delta: float) -> void:
	if timed_schedule == null:
		return

	timed_schedule.advance_time(delta)

	var allies: Array = get_tree().get_nodes_in_group("allies") if get_tree() else []
	if drop_pod_manager:
		drop_pod_manager.process_strikes(delta, allies)

	if nydus_crater_manager:
		nydus_crater_manager.process_craters(delta)


func _on_drop_pod_due(_pod_index: int, _game_time: float) -> void:
	if drop_pod_manager == null:
		return
	var allies: Array = get_tree().get_nodes_in_group("allies") if get_tree() else []
	var valid_units: Array = drop_pod_manager.find_valid_targets(allies)
	if not valid_units.is_empty():
		var target_pos: Vector3 = (valid_units[0] as Node3D).global_position
		drop_pod_manager.schedule_strike(target_pos)
		if SignalBus.has_signal("drop_pod_incoming"):
			SignalBus.drop_pod_incoming.emit(target_pos, drop_pod_manager.warning_delay)


func _on_scheduled_attack_warning(wave_index: int, leader_name: String, seconds_left: float, dir: Vector3) -> void:
	if SignalBus.has_signal("scheduled_attack_warned"):
		SignalBus.scheduled_attack_warned.emit(wave_index, leader_name, seconds_left, dir)


func _on_scheduled_attack_dispatched(wave_index: int, leader_data: Dictionary, _hive: Vector3, _base: Vector3) -> void:
	if SignalBus.has_signal("scheduled_attack_started"):
		SignalBus.scheduled_attack_started.emit(wave_index, leader_data)
	if state_label:
		state_label.text = "¡ASALTO DE LA COLMENA: %s EN CAMINO!" % leader_data.get("leader_name", "Líder")
		state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))


func _on_nydus_tremor_started(crater_index: int, pos: Vector3, _delay: float) -> void:
	var tier_data: Dictionary = timed_schedule.get_nydus_tier(spawners_destroyed_count)
	var tier_name: String = tier_data.get("tier_name", "Nydus Worm")
	if SignalBus.has_signal("nydus_tremor_alert"):
		SignalBus.nydus_tremor_alert.emit(crater_index, pos, tier_name)



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_toggle_debug_telemetry()


func _setup_start_modal() -> void:
	# Initial Top Bar Sync from Bank
	var bank: Dictionary = BankManager.load_bank()
	var sess := _get_game_session()
	var initial_minerals: int = 12000
	var max_sup: int = 80
	if sess:
		initial_minerals = sess.get_initial_minerals(false)
		max_sup = sess.get_max_supply()

	if economy_manager:
		economy_manager.reset(initial_minerals)

	if sc2_hud_root:
		sc2_hud_root.update_veterancy(bank.get("veterancy_level", 1))
		sc2_hud_root.update_difficulty(SFEDifficultyManager.get_difficulty_name(), SFEDifficultyManager.get_difficulty())
		if economy_manager:
			sc2_hud_root.update_minerals(economy_manager.current_minerals)
		sc2_hud_root.update_supply(1, max_sup)

	start_modal = SFEStartModal.new()
	start_modal.name = "SFEStartModal"
	add_child(start_modal)
	start_modal.deployment_confirmed.connect(_on_deployment_confirmed)


func _get_game_session() -> Node:
	if Engine.has_singleton("GameSession"):
		return Engine.get_singleton("GameSession")
	var tree := _get_tree_safe()
	if tree and tree.root and tree.root.has_node("GameSession"):
		return tree.root.get_node("GameSession")
	return null


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _get_tree_safe() -> SceneTree:
	var t := get_tree()
	if t:
		return t
	return Engine.get_main_loop() as SceneTree


func _on_deployment_confirmed(selected_hero: HeroData, diff_tier: int, is_random: bool) -> void:
	# 1. Apply difficulty scaling
	if difficulty_manager:
		difficulty_manager.set_difficulty(diff_tier)
	elif SFEDifficultyManager.instance:
		SFEDifficultyManager.set_difficulty(diff_tier)

	# 2. Start GameSession and calculate initial minerals per SFE5 wiki rules
	var sess := _get_game_session()
	var initial_mins: int = 12000
	var max_sup: int = 80
	if sess:
		sess.start_new_session(diff_tier, 1)
		initial_mins = sess.get_initial_minerals(is_random)
		max_sup = sess.get_max_supply()
	else:
		initial_mins = 15000 if is_random else 12000

	if economy_manager:
		economy_manager.reset(initial_mins)

	# 3. Bind Selected Hero Data & Visuals
	if selected_hero and active_hero:
		active_hero.hero_data = selected_hero
		var diff_paths := [
			"res://data/difficulties/casual.tres",
			"res://data/difficulties/normal.tres",
			"res://data/difficulties/hard.tres",
			"res://data/difficulties/brutal.tres",
			"res://data/difficulties/torment.tres",
			"res://data/difficulties/impossible.tres"
		]
		if diff_tier >= 0 and diff_tier < diff_paths.size() and ResourceLoader.exists(diff_paths[diff_tier]):
			active_hero.current_difficulty_data = load(diff_paths[diff_tier])

		if not active_hero.revive_countdown_updated.is_connected(_on_hero_revive_countdown_updated):
			active_hero.revive_countdown_updated.connect(_on_hero_revive_countdown_updated)
		if not active_hero.hero_respawned.is_connected(_on_hero_respawned):
			active_hero.hero_respawned.connect(_on_hero_respawned)

		active_hero._bind_hero_data()
		active_hero.apply_archetype_visuals(selected_hero)
		if rts_controller:
			rts_controller.clear_selection()
			rts_controller.select_unit(active_hero)
			var bus := _get_signal_bus()
			if bus and bus.has_signal("units_selected"):
				bus.units_selected.emit([active_hero])
		if player_console:
			player_console.target_unit = active_hero

	# 4. Update SC2 Top Bar
	if sc2_hud_root:
		sc2_hud_root.update_difficulty(SFEDifficultyManager.get_difficulty_name(), diff_tier)
		if economy_manager:
			sc2_hud_root.update_minerals(economy_manager.current_minerals)
		sc2_hud_root.update_supply(1, max_sup)
		sc2_hud_root.top_wave_label.text = "¡OLEADA ENTRANTE EN 5s!"
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	start_modal = null

	# SFE5 Gameplay Loop Activation (Task 3.9)
	var is_waves_mode: bool = false
	if sess and "active_mode" in sess and sess.active_mode and "use_waves_mode" in sess.active_mode:
		is_waves_mode = sess.active_mode.use_waves_mode

	var t := _get_tree_safe()
	if is_waves_mode:
		# Legacy wave progression mode
		if t:
			for s in range(5, 0, -1):
				if not is_inside_tree() or (wave_manager and wave_manager.is_wave_in_progress):
					return
				if sc2_hud_root and is_instance_valid(sc2_hud_root) and sc2_hud_root.top_wave_label:
					sc2_hud_root.top_wave_label.text = "¡OLEADA ENTRANTE EN %ds!" % s
					sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				await t.create_timer(1.0).timeout
			if wave_manager and not wave_manager.is_wave_in_progress:
				wave_manager.start_next_wave()
	else:
		# Standard SFE5 Procedural Spawner Chain
		if t:
			for s in range(5, 0, -1):
				if not is_inside_tree():
					return
				if sc2_hud_root and is_instance_valid(sc2_hud_root) and sc2_hud_root.top_wave_label:
					sc2_hud_root.top_wave_label.text = "¡ENGENDRADORES ACTIVÁNDOSE EN %ds!" % s
					sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				await t.create_timer(1.0).timeout
			if spawner_chain:
				var first_spawner = spawner_chain.get_spawner(&"spawner_01")
				if first_spawner:
					first_spawner.unlock()
				if sc2_hud_root and sc2_hud_root.top_wave_label:
					sc2_hud_root.top_wave_label.text = "¡CADENA DE ENGENDRADORES ACTIVA! Quedan %d nidos." % spawner_chain.get_remaining_spawner_count()
					sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))


func _on_hero_revive_countdown_updated(remaining: float, total: float) -> void:
	if sc2_hud_root and is_instance_valid(sc2_hud_root):
		sc2_hud_root.update_revive_countdown(remaining, total)


func _on_hero_respawned(hero: Node) -> void:
	if sc2_hud_root and is_instance_valid(sc2_hud_root):
		sc2_hud_root.update_revive_countdown(0.0, 0.0)


func _prepare_navigation_and_gates() -> void:
	var t := _get_tree_safe()
	var gates: Array[Node] = t.get_nodes_in_group("gates") if t else []
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
	var cc_pos := Vector3(-24.0, 0.0, 24.0)
	if command_center:
		cc_pos = command_center.global_position
	elif not get_tree().get_nodes_in_group("command_centers").is_empty():
		var cc_node: Node3D = get_tree().get_nodes_in_group("command_centers")[0] as Node3D
		if cc_node:
			cc_pos = cc_node.global_position
	
	swarm_simulation.register_goal(cc_pos)

	# Register perimeter structures (WallSegment, GateStructure, Bunkers, Armory) as dynamic obstacles
	_register_all_perimeter_obstacles()


func _setup_spawner_network() -> void:
	if not budget_manager:
		budget_manager = EnemyBudgetManager.new(300)
		budget_manager.set_simulation(swarm_simulation)
	
	var sess := _get_game_session()
	var seed_val = sess.active_seed if sess and "active_seed" in sess else 12345
	var map_seed := MapSeed.new(seed_val)
	map_generator = MapGenerator.new(map_seed)
	
	var layout_plan := map_generator.generate_layout_plan(3)
	spawner_chain = map_generator.spawn_spawner_chain(self, layout_plan, budget_manager, swarm_simulation)
	
	spawner_chain.spawner_unlocked.connect(_on_spawner_unlocked)
	spawner_chain.spawner_chain_step_completed.connect(_on_spawner_step_completed)
	spawner_chain.all_spawners_destroyed.connect(_on_all_spawners_cleared)


func _on_spawner_unlocked(spawner: SpawnerNode) -> void:
	if sc2_hud_root and sc2_hud_root.top_wave_label:
		sc2_hud_root.top_wave_label.text = "¡OBJETIVO: DESTRUYE %s!" % spawner.spawner_name.to_upper()
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))


func _on_spawner_step_completed(_sid: StringName, remaining: int) -> void:
	spawners_destroyed_count += 1
	if sc2_hud_root and sc2_hud_root.top_wave_label:
		if remaining > 0:
			sc2_hud_root.top_wave_label.text = "¡ENGENDRADOR DESTRUIDO! Quedan %d engendradores." % remaining
			sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			sc2_hud_root.top_wave_label.text = "¡TODOS LOS ENGENDRADORES ERRADICADOS!"
			sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))


func _on_all_spawners_cleared() -> void:
	if is_game_over:
		return
	is_game_over = true
	_save_bank_progress(false)
	
	var total_min := economy_manager.current_minerals if economy_manager else 0
	var modal := SFEGameOverModal.new()
	modal.setup(
		true,
		match_timer,
		session_kills,
		total_min,
		spawner_chain.get_total_spawner_count() if spawner_chain else 3,
		spawner_chain.get_total_spawner_count() if spawner_chain else 3,
		SFEDifficultyManager.get_difficulty_name()
	)
	add_child(modal)


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
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true, 180)
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
			var half_size: Vector3 = Vector3(1.75, 1.25, 1.75)
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true, 80)
		elif s.name.to_lower().contains("armory") or s.is_in_group("armory"):
			var half_size: Vector3 = Vector3(1.5, 1.2, 1.5)
			swarm_simulation.register_obstacle_aabb(s, s.global_position - half_size, s.global_position + half_size, true, 90)


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
		var bus := _get_signal_bus()
		if bus and bus.has_signal("units_selected"):
			bus.units_selected.emit([active_hero])


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
	var bus := _get_signal_bus()
	if bus:
		if bus.has_signal("structure_destroyed") and not bus.structure_destroyed.is_connected(_on_structure_destroyed):
			bus.structure_destroyed.connect(_on_structure_destroyed)
		if bus.has_signal("structure_damaged") and not bus.structure_damaged.is_connected(_on_structure_damaged):
			bus.structure_damaged.connect(_on_structure_damaged)
		if bus.has_signal("gate_state_changed") and not bus.gate_state_changed.is_connected(_on_gate_state_changed):
			bus.gate_state_changed.connect(_on_gate_state_changed)
		if bus.has_signal("wave_started") and not bus.wave_started.is_connected(_on_wave_started):
			bus.wave_started.connect(_on_wave_started)
		if bus.has_signal("wave_completed") and not bus.wave_completed.is_connected(_on_wave_completed):
			bus.wave_completed.connect(_on_wave_completed)
		if bus.has_signal("wave_enemy_count_changed") and not bus.wave_enemy_count_changed.is_connected(_on_wave_enemy_count_changed):
			bus.wave_enemy_count_changed.connect(_on_wave_enemy_count_changed)
		if bus.has_signal("enemy_died") and not bus.enemy_died.is_connected(_on_enemy_died):
			bus.enemy_died.connect(_on_enemy_died)
		if bus.has_signal("base_destroyed") and not bus.base_destroyed.is_connected(_on_base_destroyed):
			bus.base_destroyed.connect(_on_base_destroyed)

	if start_wave_btn and not start_wave_btn.pressed.is_connected(_on_start_wave_pressed):
		start_wave_btn.pressed.connect(_on_start_wave_pressed)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_pressed):
		restart_btn.pressed.connect(_on_restart_pressed)


func _setup_boss_health_bar_ui() -> void:
	var existing = get_node_or_null("BossHealthBarUI")
	if existing is BossHealthBarUI:
		boss_health_bar_ui = existing
	else:
		var boss_ui_scene: PackedScene = load("res://ui/boss_health_bar_ui.tscn")
		if boss_ui_scene:
			boss_health_bar_ui = boss_ui_scene.instantiate() as BossHealthBarUI
			boss_health_bar_ui.name = "BossHealthBarUI"
			add_child(boss_health_bar_ui)
		else:
			boss_health_bar_ui = BossHealthBarUI.new()
			boss_health_bar_ui.name = "BossHealthBarUI"
			add_child(boss_health_bar_ui)

	if boss_health_bar_ui:
		boss_health_bar_ui.add_to_group("boss_ui")

	if wave_manager and not wave_manager.boss_spawn_requested.is_connected(_on_boss_spawn_requested):
		wave_manager.boss_spawn_requested.connect(_on_boss_spawn_requested)


func _on_boss_spawn_requested(boss_scene: PackedScene, spawn_pos: Vector3) -> void:
	# Ensure boss is bound to boss health bar UI
	var target_boss: Node3D = null
	var bosses: Array[Node] = get_tree().get_nodes_in_group("bosses")
	for b in bosses:
		if is_instance_valid(b) and b is Node3D and not (b is BossOmegaUltralisk3D):
			target_boss = b as Node3D
			break

	if not target_boss and boss_scene:
		target_boss = boss_scene.instantiate() as Node3D
		add_child(target_boss)
		target_boss.global_position = spawn_pos

	if target_boss and boss_health_bar_ui:
		boss_health_bar_ui.bind_boss(target_boss)

	if state_label and target_boss:
		var b_name: String = target_boss.get("boss_name") if "boss_name" in target_boss else "JEFE"
		state_label.text = "¡ALERTA! ¡%s HA ENTRADO EN EL COMBATE!" % b_name.to_upper()
		state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))


func _play_sfx_3d(sfx_name: StringName, pos: Vector3) -> void:
	var sfx = Engine.get_singleton("SFXManager") if Engine.has_singleton("SFXManager") else null
	if not sfx and has_node("/root/SFXManager"):
		sfx = get_node("/root/SFXManager")
	if sfx and sfx.has_method("play_sfx_3d"):
		sfx.play_sfx_3d(sfx_name, pos)


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

	# 1. Swarm Units Assault on Perimeter & Base (Zergling, Roach, Baneling, Hydralisk)
	var active_limit: int = sdata.active_count
	var processed: int = 0

	for i in range(cap):
		if alive[i] == 0:
			continue

		var arch_id: int = sdata.archetype_ids[i]
		var unit_pos := Vector3(px[i], 0.0, pz[i])

		# Strain 1: Baneling (Archetype 2) Kamikaze Detonation
		if arch_id == 2:
			var detonated: bool = false
			# Proximity check: within 1.4m of hero, marine, wall, bunker, CC
			for s in structures:
				if not is_instance_valid(s) or not (s is Node3D):
					continue
				var s_rad: float = 2.0
				if s is CommandCenter:
					s_rad = 4.0
				elif s is GateStructure or s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
					s_rad = 2.5
				if unit_pos.distance_to((s as Node3D).global_position) <= (1.4 + s_rad):
					detonated = true
					break

			if not detonated:
				for a in allies:
					if not is_instance_valid(a) or not (a is Node3D):
						continue
					if unit_pos.distance_to((a as Node3D).global_position) <= (1.4 + 0.6):
						detonated = true
						break

			if detonated:
				_execute_baneling_detonation(unit_pos, i, structures, allies)
				processed += 1
				if processed >= active_limit:
					break
				continue

		# Strain 2: Hydralisk (Archetype 3) Ranged Artillery Attack (Range 9.0m)
		elif arch_id == 3:
			atk_tmr[i] = maxf(0.0, atk_tmr[i] - dt)
			if atk_tmr[i] <= 0.0:
				var hydra_range: float = atk_rng[i] if atk_rng[i] > 0.0 else 9.0
				var hit_target: Node3D = null
				var hit_struct_type: int = CombatTypes.StructureType.NONE

				for s in structures:
					if not is_instance_valid(s) or not (s is Node3D):
						continue
					var s_rad: float = 2.0
					if s is CommandCenter:
						s_rad = 4.0
					elif s is GateStructure or s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
						s_rad = 2.5
					if unit_pos.distance_to((s as Node3D).global_position) <= (hydra_range + s_rad):
						hit_target = s as Node3D
						if s is WallSegment:
							hit_struct_type = CombatTypes.StructureType.WALL_REINFORCED
						elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
							hit_struct_type = CombatTypes.StructureType.BUNKER
						break

				if not hit_target:
					for a in allies:
						if not is_instance_valid(a) or not (a is Node3D):
							continue
						if unit_pos.distance_to((a as Node3D).global_position) <= (hydra_range + 0.6):
							hit_target = a as Node3D
							break

				if hit_target:
					atk_tmr[i] = atk_cd[i] if atk_cd[i] > 0.0 else 0.85
					_execute_hydralisk_artillery_attack(unit_pos, hit_target, hit_struct_type, structures, allies)

			processed += 1
			if processed >= active_limit:
				break
			continue

		# Standard Strain: Zergling (0) & Roach (1) Melee
		else:
			atk_tmr[i] = maxf(0.0, atk_tmr[i] - dt)
			if atk_tmr[i] <= 0.0:
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
					_on_swarm_unit_killed(target_idx, ally, target_pos, 5)

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
						_on_swarm_unit_killed(b_target_idx, b_node, b_target_pos, 5)


## Baneling Instantaneous Kamikaze Detonation: 40 AoE unit dmg, 140 structural dmg (3.5x), despawn, SFX
func _execute_baneling_detonation(detonation_pos: Vector3, unit_idx: int, structures: Array[Node], allies: Array[Node]) -> void:
	_play_sfx_3d(&"baneling_explode", detonation_pos)
	if combat_vfx_pool:
		combat_vfx_pool.spawn_acid_burst(detonation_pos)

	# 40.0 Unit AoE Damage in 1.4m radius
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			if detonation_pos.distance_to((a as Node3D).global_position) <= (1.4 + 0.6):
				var res = SFECombatEngine.calculate_damage(
					40.0,
					CombatTypes.DamageType.PHYSICAL,
					a.get("flat_armor") if "flat_armor" in a else 1.0,
					0,
					CombatTypes.StructureType.NONE,
					a is HeroUnit3D,
					true
				)
				if a.has_method("take_damage_context"):
					a.take_damage_context(40.0, CombatTypes.DamageType.PHYSICAL, a is HeroUnit3D, 0)
				elif a.has_method("take_damage"):
					a.take_damage(res.damage_dealt)

	# 140.0 Structural Damage (3.5x multiplier against walls/bunkers/CC)
	for s in structures:
		if is_instance_valid(s) and s is Node3D:
			var s_rad: float = 2.0
			var s_type: int = CombatTypes.StructureType.NONE
			if s is CommandCenter:
				s_rad = 4.0
			elif s is GateStructure:
				s_rad = 2.5
			elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
				s_rad = 2.5
				s_type = CombatTypes.StructureType.BUNKER
			elif s is WallSegment:
				s_type = CombatTypes.StructureType.WALL_REINFORCED

			if detonation_pos.distance_to((s as Node3D).global_position) <= (1.4 + s_rad):
				var res = SFECombatEngine.calculate_damage(
					140.0,
					CombatTypes.DamageType.PHYSICAL,
					0.0,
					0,
					s_type,
					false,
					true
				)
				if s.has_method("take_damage_context"):
					s.take_damage_context(140.0, CombatTypes.DamageType.PHYSICAL, false, 0)
				elif s.has_method("take_damage"):
					s.take_damage(res.damage_dealt)

	# Despawn from Swarm Simulation SoA & Notify Wave Manager
	if swarm_simulation:
		swarm_simulation.despawn_unit(unit_idx)
	if wave_manager:
		wave_manager.on_swarm_unit_died(8)


## Baneling Premature Pop (Slain before reaching target): 50% damage in 2.0m splash radius
func _execute_baneling_premature_pop(pop_pos: Vector3) -> void:
	_play_sfx_3d(&"baneling_explode", pop_pos)
	if combat_vfx_pool:
		combat_vfx_pool.spawn_acid_burst(pop_pos)

	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")

	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			if pop_pos.distance_to((a as Node3D).global_position) <= (2.0 + 0.6):
				var res = SFECombatEngine.calculate_damage(
					20.0,
					CombatTypes.DamageType.PHYSICAL,
					a.get("flat_armor") if "flat_armor" in a else 1.0,
					0,
					CombatTypes.StructureType.NONE,
					a is HeroUnit3D,
					true
				)
				if a.has_method("take_damage"):
					a.take_damage(res.damage_dealt)

	for s in structures:
		if is_instance_valid(s) and s is Node3D:
			var s_rad: float = 2.0
			var s_type: int = CombatTypes.StructureType.NONE
			if s is CommandCenter:
				s_rad = 4.0
			elif s is GateStructure:
				s_rad = 2.5
			elif s.name.to_lower().contains("bunker") or s.is_in_group("bunkers"):
				s_rad = 2.5
				s_type = CombatTypes.StructureType.BUNKER
			elif s is WallSegment:
				s_type = CombatTypes.StructureType.WALL_REINFORCED

			if pop_pos.distance_to((s as Node3D).global_position) <= (2.0 + s_rad):
				var res = SFECombatEngine.calculate_damage(
					70.0,
					CombatTypes.DamageType.PHYSICAL,
					0.0,
					0,
					s_type,
					false,
					true
				)
				if s.has_method("take_damage"):
					s.take_damage(res.damage_dealt)


## Hydralisk Ranged Artillery: 28 m/s piercing spines dealing 16 primary dmg & penetrating 8 secondary dmg
func _execute_hydralisk_artillery_attack(
	origin: Vector3,
	primary_target: Node3D,
	primary_struct_type: int,
	structures: Array[Node],
	allies: Array[Node]
) -> void:
	var raw_primary: float = 16.0
	var primary_armor: float = primary_target.get("flat_armor") if "flat_armor" in primary_target else 1.0
	if primary_target.is_in_group("structures") or primary_struct_type != CombatTypes.StructureType.NONE:
		primary_armor = 0.0

	var res_primary = SFECombatEngine.calculate_damage(
		raw_primary,
		CombatTypes.DamageType.PHYSICAL,
		primary_armor,
		0,
		primary_struct_type,
		primary_target is HeroUnit3D
	)

	if primary_target.has_method("take_damage_context"):
		primary_target.take_damage_context(raw_primary, CombatTypes.DamageType.PHYSICAL, primary_target is HeroUnit3D, 0)
	elif primary_target.has_method("take_damage"):
		primary_target.take_damage(res_primary.damage_dealt)

	_play_sfx_3d(&"hydra_spine", origin)
	if combat_vfx_pool:
		combat_vfx_pool.spawn_tracer(origin + Vector3(0.0, 1.2, 0.0), primary_target.global_position + Vector3(0.0, 0.8, 0.0))

	# Secondary Target Penetration (50% = 8.0 damage to unit/structure in line behind)
	var spine_dir: Vector3 = (primary_target.global_position - origin)
	spine_dir.y = 0.0
	if spine_dir.length_squared() > 0.01:
		spine_dir = spine_dir.normalized()
		var secondary_target: Node3D = null
		var secondary_struct_type: int = CombatTypes.StructureType.NONE
		var best_dist: float = INF

		var candidates: Array[Node] = []
		candidates.append_array(allies)
		candidates.append_array(structures)

		for c in candidates:
			if not is_instance_valid(c) or not (c is Node3D) or c == primary_target:
				continue
			var to_cand: Vector3 = (c as Node3D).global_position - primary_target.global_position
			to_cand.y = 0.0
			var dist: float = to_cand.length()
			if dist > 0.3 and dist <= 6.5:
				var dot: float = spine_dir.dot(to_cand.normalized())
				if dot > 0.55 and dist < best_dist:
					best_dist = dist
					secondary_target = c as Node3D
					if c is WallSegment:
						secondary_struct_type = CombatTypes.StructureType.WALL_REINFORCED
					elif c.name.to_lower().contains("bunker") or c.is_in_group("bunkers"):
						secondary_struct_type = CombatTypes.StructureType.BUNKER

		if secondary_target:
			var raw_secondary: float = 8.0
			var sec_armor: float = secondary_target.get("flat_armor") if "flat_armor" in secondary_target else 1.0
			if secondary_target.is_in_group("structures") or secondary_struct_type != CombatTypes.StructureType.NONE:
				sec_armor = 0.0

			var res_secondary = SFECombatEngine.calculate_damage(
				raw_secondary,
				CombatTypes.DamageType.PHYSICAL,
				sec_armor,
				0,
				secondary_struct_type,
				secondary_target is HeroUnit3D
			)
			if secondary_target.has_method("take_damage_context"):
				secondary_target.take_damage_context(raw_secondary, CombatTypes.DamageType.PHYSICAL, secondary_target is HeroUnit3D, 0)
			elif secondary_target.has_method("take_damage"):
				secondary_target.take_damage(res_secondary.damage_dealt)

			if combat_vfx_pool:
				combat_vfx_pool.spawn_tracer(primary_target.global_position + Vector3(0.0, 0.8, 0.0), secondary_target.global_position + Vector3(0.0, 0.8, 0.0))


## Centralized handler for swarm unit death from allied attacks, bunkers, and skills
func _on_swarm_unit_killed(unit_idx: int, killer: Node, pos: Vector3, bounty_val: int = 5) -> void:
	var sdata = swarm_simulation.swarm_data
	var arch_id: int = sdata.archetype_ids[unit_idx]

	if combat_vfx_pool:
		combat_vfx_pool.spawn_acid_burst(pos)

	# 50% premature pop mechanic for Banelings killed before reaching target
	if arch_id == 2:
		_execute_baneling_premature_pop(pos)

	var inc_params: IncomeParams = _create_swarm_income_params(arch_id)
	var bounty: int = award_kill_bounty(null, killer, bounty_val, EconomyTypes.Faction.ALLIED, CombatTypes.DamageType.PHYSICAL, inc_params)
	var cat_color: Color = get_category_color(inc_params.category)
	FloatingTextManager.spawn_text(self, pos, "+%d Minerals" % bounty, cat_color)
	if active_hero:
		active_hero.gain_experience(15)
	session_kills += 1
	if wave_manager:
		wave_manager.on_swarm_unit_died(bounty_val)


## Awards mineral kill bounty honoring the strict Crossfire Nullification Rule (Requirement R3) and SFE5 Master Income Formula.
func award_kill_bounty(
	victim: Object,
	killer: Object,
	base_bounty: int,
	killer_faction: int = EconomyTypes.Faction.ALLIED,
	lethal_damage_type: int = 0,
	p_income_params: RefCounted = null
) -> int:
	var ctx := KillContext.new(victim, killer, killer_faction, base_bounty, lethal_damage_type, p_income_params)
	if economy_manager:
		return economy_manager.process_kill(ctx)
	return 0


func _create_swarm_income_params(arch_id: int) -> IncomeParams:
	var p := IncomeParams.new()
	match arch_id:
		0: # Zergling
			p.base_health = 35.0
			p.weapon_damage = 5.0
			p.attack_period = 0.7
			p.category = "normal"
		1: # Roach
			p.base_health = 145.0
			p.weapon_damage = 16.0
			p.attack_period = 2.0
			p.category = "normal"
		2: # Baneling
			p.base_health = 30.0
			p.weapon_damage = 20.0
			p.attack_period = 0.8
			p.category = "normal"
		3: # Hydralisk
			p.base_health = 80.0
			p.weapon_damage = 12.0
			p.attack_period = 0.83
			p.category = "normal"
		_:
			p.base_health = 35.0
			p.weapon_damage = 5.0
			p.attack_period = 0.7
			p.category = "normal"
	p.category_multiplier = 1.0
	return p


func _create_enemy_income_params(enemy: Node) -> IncomeParams:
	var p := IncomeParams.new()
	if enemy.is_in_group("bosses") or enemy.is_in_group("secret_boss"):
		p.base_health = enemy.get("max_health") if "max_health" in enemy else 5000.0
		p.weapon_damage = enemy.get("attack_damage") if "attack_damage" in enemy else 65.0
		p.attack_period = enemy.get("attack_cooldown") if "attack_cooldown" in enemy else 1.2
		p.category = "map_boss"
		p.category_multiplier = 6.0
	elif enemy.is_in_group("structures"):
		p.base_health = enemy.get("max_health") if "max_health" in enemy else 1500.0
		p.weapon_damage = 0.0
		p.has_weapon = false
		p.category = "structure"
		p.category_multiplier = 8.0
	elif enemy.is_in_group("heroic"):
		p.base_health = enemy.get("max_health") if "max_health" in enemy else 250.0
		p.weapon_damage = enemy.get("attack_damage") if "attack_damage" in enemy else 20.0
		p.attack_period = enemy.get("attack_cooldown") if "attack_cooldown" in enemy else 1.0
		p.category = "heroic"
		p.category_multiplier = 4.0
	elif "max_health" in enemy:
		p.base_health = enemy.max_health
		p.weapon_damage = enemy.get("attack_damage") if "attack_damage" in enemy else 5.0
		p.attack_period = enemy.get("attack_cooldown") if "attack_cooldown" in enemy else 0.5
		p.category = "normal"
		p.category_multiplier = 1.0
	else:
		return null

	var sess := _get_game_session()
	if sess and sess.pedestal_bonus_active:
		p.pedestal_bonus = 25

	return p


func get_category_color(category: String) -> Color:
	match category.to_lower():
		"structure":
			return Color(0.2, 1.0, 0.3) # Verde estructura
		"heroic":
			return Color(1.0, 0.9, 0.2) # Amarillo heroica
		"elite", "map_boss":
			return Color(1.0, 0.55, 0.1) # Naranja élite
		"boss", "summoned_boss", "pinnacle_boss":
			return Color(1.0, 0.25, 0.25) # Rojo jefe
		_:
			return Color(0.2, 0.95, 1.0) # Cyan normal


func _on_hero_skill_cast(skill: Variant, target: Variant) -> void:
	if not swarm_simulation or not swarm_simulation.spatial_hash:
		return
	if skill == null:
		return

	var radius: float = skill.area_radius if "area_radius" in skill else 0.0
	var power: float = skill.base_power if "base_power" in skill else 0.0
	var _dmg_type: int = skill.damage_type if "damage_type" in skill else CombatTypes.DamageType.SPELL

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
			_on_swarm_unit_killed(unit_idx, active_hero, victim_pos, 5)


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
	var sess := _get_game_session()
	if sess:
		sess.pedestal_bonus_active = true
	if state_label:
		state_label.text = "¡PUZZLE DE PEDESTALES RESUELTO (+25 BONO DE BOTÍN)!"
		state_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))


func _on_gate_state_changed(gate: Node, is_open: bool) -> void:
	if swarm_simulation and is_instance_valid(gate) and gate is Node3D:
		var g: Node3D = gate as Node3D
		var half_size: Vector3 = Vector3(3.1, 1.6, 0.8)
		var gate_cost: int = 1 if is_open else 20
		swarm_simulation.register_obstacle_aabb(g, g.global_position - half_size, g.global_position + half_size, not is_open, gate_cost)


func _on_structure_destroyed(structure: Node) -> void:
	if structure is CommandCenter:
		var bus := _get_signal_bus()
		if bus and bus.has_signal("base_destroyed"):
			bus.base_destroyed.emit()
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

	# Auto-start subsequent waves automatically after 8-second tactical preparation
	var t := _get_tree_safe()
	if t:
		for s in range(8, 0, -1):
			if not is_inside_tree() or (wave_manager and wave_manager.is_wave_in_progress):
				return
			if sc2_hud_root and is_instance_valid(sc2_hud_root) and sc2_hud_root.top_wave_label:
				sc2_hud_root.top_wave_label.text = "FASE TÁCTICA  |  ¡SIGUIENTE OLEADA EN %ds!" % s
				sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			await t.create_timer(1.0).timeout
		if wave_manager and not wave_manager.is_wave_in_progress:
			wave_manager.start_next_wave()


func _on_enemy_died(enemy: Node, reward: int) -> void:
	var killer_faction: int = EconomyTypes.Faction.ALLIED
	var killer_node: Object = active_hero
	var enemy_pos := Vector3.ZERO
	var category: String = "normal"
	var inc_params: IncomeParams = null

	if is_instance_valid(enemy):
		if enemy.has_meta("killer_faction"):
			killer_faction = enemy.get_meta("killer_faction")
		if enemy.has_meta("killer"):
			killer_node = enemy.get_meta("killer")
		if enemy is Node3D:
			enemy_pos = (enemy as Node3D).global_position
			if combat_vfx_pool:
				combat_vfx_pool.spawn_acid_burst(enemy_pos)

		inc_params = _create_enemy_income_params(enemy)
		if inc_params:
			category = inc_params.category

	var bounty: int = award_kill_bounty(enemy, killer_node, reward, killer_faction, 0, inc_params)
	if bounty > 0 and enemy_pos != Vector3.ZERO:
		FloatingTextManager.spawn_text(self, enemy_pos, "+%d Minerals" % bounty, get_category_color(category))
	if active_hero:
		active_hero.gain_experience(reward * 3)
	session_kills += 1


func _toggle_debug_telemetry() -> void:
	if debug_telemetry_panel == null:
		_create_debug_telemetry_panel()
	debug_telemetry_panel.visible = not debug_telemetry_panel.visible
	if debug_telemetry_panel.visible:
		_update_debug_telemetry()


func _create_debug_telemetry_panel() -> void:
	debug_telemetry_panel = PanelContainer.new()
	debug_telemetry_panel.name = "SFE5DebugTelemetryPanel"
	debug_telemetry_panel.anchor_left = 1.0
	debug_telemetry_panel.anchor_right = 1.0
	debug_telemetry_panel.anchor_top = 0.0
	debug_telemetry_panel.anchor_bottom = 0.0
	debug_telemetry_panel.offset_left = -420.0
	debug_telemetry_panel.offset_right = -15.0
	debug_telemetry_panel.offset_top = 45.0
	debug_telemetry_panel.offset_bottom = 265.0
	debug_telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.90)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.85, 1.0, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	debug_telemetry_panel.add_theme_stylebox_override("panel", style)

	debug_telemetry_label = Label.new()
	debug_telemetry_label.name = "TelemetryLabel"
	debug_telemetry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_telemetry_label.add_theme_font_size_override("font_size", 11)
	debug_telemetry_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	debug_telemetry_panel.add_child(debug_telemetry_label)

	if sc2_hud_root:
		sc2_hud_root.add_child(debug_telemetry_panel)
	else:
		add_child(debug_telemetry_panel)


func _update_debug_telemetry() -> void:
	if not debug_telemetry_label or not economy_manager:
		return
	var stats = economy_manager.get_economy_stats()
	var last = stats.get("last_kill", {})
	var lines: Array[String] = []
	lines.append("=== SFE5 ECONOMY TELEMETRY (F3) ===")
	lines.append("Wallet: %d | Total Ganado: %d | Gastado: %d" % [
		stats.get("current_minerals", 0),
		stats.get("total_earned", 0),
		stats.get("total_spent", 0)
	])
	lines.append("Tasa: %.1f Min/min | Kills: %d, Initial: %d, Puzzles: %d" % [
		stats.get("minerals_per_minute", 0.0),
		stats.get("by_source", {}).get("kill", 0),
		stats.get("by_source", {}).get("initial", 0),
		stats.get("by_source", {}).get("puzzle", 0)
	])
	lines.append("--------------------------------------------------")
	if last.is_empty():
		lines.append("Última Baja: [Ninguna registrada]")
	else:
		lines.append("Última Baja: %s [%s]" % [last.get("victim_name", "N/A"), last.get("category", "normal").to_upper()])
		lines.append("HP: %.0f | Escudo: %.0f | Daño: %.1f | Periodo: %.2fs" % [
			last.get("hp", 0.0), last.get("shield", 0.0), last.get("damage", 0.0), last.get("period", 1.0)
		])
		lines.append("Mult Dificultad: x%.2f | Jugadores: %d | Split: %s" % [
			last.get("difficulty_mult", 1.0), last.get("player_count", 1), str(last.get("split_income", false))
		])
		lines.append("Mult Categoría: x%.1f | Bono Pedestal: +%.0f" % [
			last.get("category_mult", 1.0), last.get("pedestal_bonus", 0.0)
		])
		lines.append("Botín Otorgado: +%d Minerales" % last.get("bounty", 0))
	lines.append("==================================================")
	debug_telemetry_label.text = "\n".join(lines)


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
	if is_game_over:
		return
	is_game_over = true
	_save_bank_progress(true)
	if game_over_panel:
		game_over_panel.visible = true
	
	var total_min := economy_manager.current_minerals if economy_manager else 0
	var cleared := spawners_destroyed_count
	var total_sp := spawner_chain.get_total_spawner_count() if spawner_chain else 3
	var modal := SFEGameOverModal.new()
	modal.setup(
		false,
		match_timer,
		session_kills,
		total_min,
		cleared,
		total_sp,
		SFEDifficultyManager.get_difficulty_name()
	)
	add_child(modal)


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
