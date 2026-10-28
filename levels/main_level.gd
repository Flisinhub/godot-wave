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
const StoryPhaseManager = preload("res://core/story/story_phase_manager.gd")
const BossBrutalisk3D = preload("res://entities/enemies/boss_brutalisk_3d.gd")
const BossHybrid3D = preload("res://entities/enemies/boss_hybrid_3d.gd")
const BossNydus3D = preload("res://entities/enemies/boss_nydus_3d.gd")
const DebugConsole = preload("res://core/modes/debug_console.gd")
const SecretManager = preload("res://core/events/secret_manager.gd")
const PinnacleBossCatalog = preload("res://core/bosses/pinnacle_boss_catalog.gd")
const PinnacleBossBase = preload("res://core/bosses/pinnacle_boss_base.gd")
const SummoningRitual = preload("res://core/bosses/summoning_ritual.gd")
const BossRewardManager = preload("res://core/bosses/boss_reward_manager.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")
const GameModeManager = preload("res://core/modes/game_mode_manager.gd")
const ModeData = preload("res://core/data/mode_data.gd")
const RankSystem = preload("res://core/meta/rank_system.gd")
const PlayerProfileStats = preload("res://core/meta/player_profile_stats.gd")
const TutorialManager = preload("res://core/tutorial/tutorial_manager.gd")
const SFESettingsModal = preload("res://ui/sfe_settings_modal.gd")
const BaseUnit3D = preload("res://entities/allies/base_unit_3d.gd")

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
var is_waves_mode: bool = false
var start_modal: SFEStartModal = null
var session_kills: int = 0
var _last_base_attack_sfx_time: float = -999.0

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

# SFE5 Story Progression (Fase 9)
var story_phase_manager: StoryPhaseManager = null

# SFE5 Timed Events & External Pressure (Fase 8)
var timed_schedule: TimedEventSchedule = null
var drop_pod_manager: DropPodManager = null
var nydus_crater_manager: NydusCraterManager = null
var scheduled_attack_manager: ScheduledAttackManager = null

# SFE5 Developer Console (Ctrl+Alt+C)
var debug_console: DebugConsole = null
var debug_cli_layer: CanvasLayer = null
var debug_cli_input: LineEdit = null
var debug_cli_output: Label = null

# SFE5 Map Secrets (Fase 9)
var secret_manager: SecretManager = null
var _outhouse_node: Node3D = null
var _mystery_box_nodes: Array[Node3D] = []
var _lucky_lizard_node: Node3D = null

# SFE5 4-Phase Match State
var nydus_spawn_timer: float = 0.0
var xelnaga_crystals: Array[Node3D] = []
var final_pinnacle_boss: Node3D = null

# Sprint C: Secrets, Teleport & Pinnacle Altars
var _fueling_station_node: Node3D = null
var _fueling_hold_timer: float = 0.0

var _base_recall_pad: Node3D = null
var _forward_bridge_pad: Node3D = null
var _is_forward_bridge_unlocked: bool = false
var _teleport_cooldown: float = 0.0

var _oracle_orb_node: Node3D = null
var _last_oracle_hint_time: int = 0

var _pinnacle_altar_odin: Node3D = null
var _pinnacle_altar_gorgon: Node3D = null
var _pinnacle_altar_kerrigan: Node3D = null
var _odin_beacons: Array[Node3D] = []
var _odin_beacons_active: int = 0
var _gorgon_hold_timer: float = 0.0

var game_mode_manager: GameModeManager = null
var tutorial_manager: TutorialManager = null
var settings_modal: SFESettingsModal = null
var nightmare_wave_timer: float = 0.0


func _ready() -> void:
	# 1. Navigation Mesh & Gate Doors Pre-Bake
	_prepare_navigation_and_gates()

	# 2. Economy & Difficulty Managers Setup
	_setup_economy_and_difficulty()

	# 3. Swarm Simulation & Flow Field Goal/Obstacle Registration
	_setup_swarm_simulation()

	# 3b. SFE5 Spawner Chain & Procedural Map (Task 3.12)
	_setup_spawner_network()

	# 3c. SFE5 Map Secrets (Outhouse, Mystery Boxes, Lucky Lizard)
	_spawn_map_secrets()

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

	if not is_waves_mode:
		if start_wave_btn:
			start_wave_btn.visible = false
		var wp := get_node_or_null("UI/WavePanel")
		if wp:
			wp.visible = false

	# 8. Milestone 6 Startup Diagnostics
	_log_milestone_6_diagnostics()

	# 9. SFE5 Pre-Mission Modal (Difficulty + Hero Selection + Player Profile)
	_setup_start_modal()

	# 10. SFE5 Player RPG Console (Alt+C)
	_setup_player_console()

	# 11. SFE5 Timed Events & Scheduled Attacks (Fase 8)
	_setup_timed_events_and_pressure()

	# 12. SFE5 Interactive Tutorial (Task 14.4)
	_setup_tutorial_manager()

	# 13. SFE5 Pause & Settings Modal (Task 12.6)
	_setup_settings_modal()


func _setup_player_console() -> void:
	player_console = PlayerConsole.new()
	player_console.name = "PlayerConsole"
	add_child(player_console)
	if active_hero:
		player_console.target_unit = active_hero
	if sc2_hud_root and not sc2_hud_root.console_open_requested.is_connected(_on_hud_console_open_requested):
		sc2_hud_root.console_open_requested.connect(_on_hud_console_open_requested)


func _on_hud_console_open_requested(tab_index: int) -> void:
	if player_console:
		player_console.open_console(active_hero, tab_index)


func _setup_tutorial_manager() -> void:
	tutorial_manager = TutorialManager.new(true)
	if sc2_hud_root:
		sc2_hud_root.update_tutorial_instruction(tutorial_manager.get_current_instruction())
	tutorial_manager.step_advanced.connect(func(_step: int, _total: int, instruction: String):
		if sc2_hud_root:
			sc2_hud_root.update_tutorial_instruction(instruction)
	)
	tutorial_manager.tutorial_completed.connect(func():
		if sc2_hud_root:
			sc2_hud_root.complete_tutorial()
	)
	if player_console:
		player_console.attribute_purchased.connect(func(_attr: String, _pts: int):
			if tutorial_manager:
				tutorial_manager.record_upgrade_bought()
		)
		player_console.buff_purchased.connect(func(_tier: int, _buff: String):
			if tutorial_manager:
				tutorial_manager.record_upgrade_bought()
		)
		player_console.racial_upgrade_purchased.connect(func(_up_id: String, _lvl: int):
			if tutorial_manager:
				tutorial_manager.record_upgrade_bought()
		)
	var bus := _get_signal_bus()
	if bus and bus.has_signal("move_command_issued"):
		bus.connect("move_command_issued", func(_target_pos: Vector3):
			if tutorial_manager:
				tutorial_manager.record_hero_moved()
		)


func _setup_settings_modal() -> void:
	settings_modal = SFESettingsModal.new()
	settings_modal.name = "SettingsModal"
	settings_modal.visible = false
	add_child(settings_modal)
	if sc2_hud_root:
		sc2_hud_root.settings_requested.connect(toggle_settings_modal)


func toggle_settings_modal() -> void:
	if not settings_modal:
		_setup_settings_modal()
	if settings_modal.visible:
		settings_modal.close()
	else:
		settings_modal.open()


func _setup_timed_events_and_pressure() -> void:
	var seed_val: int = 123456
	var sess := _get_game_session()
	if sess and "match_seed" in sess:
		seed_val = int(sess.match_seed)

	var base_origin: Vector3 = command_center.global_position if command_center else Vector3(-24.0, 0.0, 24.0)
	var hive_origin: Vector3 = Vector3(24.0, 0.0, -28.0)

	timed_schedule = TimedEventSchedule.new(seed_val)
	drop_pod_manager = DropPodManager.new(base_origin, 28.0)
	nydus_crater_manager = NydusCraterManager.new(timed_schedule)
	scheduled_attack_manager = ScheduledAttackManager.new(timed_schedule, hive_origin, base_origin)

	# Wire internal signals to SignalBus and handlers
	timed_schedule.drop_pod_due.connect(_on_drop_pod_due)
	drop_pod_manager.drop_pod_landed.connect(_on_drop_pod_landed)
	scheduled_attack_manager.attack_warning_received.connect(_on_scheduled_attack_warning)
	scheduled_attack_manager.wave_attack_dispatched.connect(_on_scheduled_attack_dispatched)
	nydus_crater_manager.crater_tremor_started.connect(_on_nydus_tremor_started)
	nydus_crater_manager.nydus_emerged.connect(_on_nydus_emerged)


func _process(delta: float) -> void:
	if not is_game_over:
		match_timer += delta
		_process_timed_events(delta)
		_check_secret_proximities(delta)
		_process_altars_and_teleports(delta)
		if game_mode_manager and game_mode_manager.is_nightmare:
			nightmare_wave_timer += delta
			if nightmare_wave_timer >= 30.0:
				nightmare_wave_timer = 0.0
				var wave_info: Dictionary = game_mode_manager.advance_nightmare_wave()
				if sc2_hud_root:
					sc2_hud_root.update_nightmare_status(wave_info.get("level", 1), wave_info.get("cycle_slot", 1), wave_info.get("type", ""))
	if sc2_hud_root:
		sc2_hud_root.update_hive_evolution(SFEDifficultyManager.hive_level, SFEDifficultyManager.cadence_timer)
		if budget_manager:
			sc2_hud_root.update_enemy_budget(budget_manager.get_living_count(), 300, budget_manager.is_saturated())
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
		if nydus_crater_manager.is_active:
			nydus_spawn_timer += delta
			if nydus_spawn_timer >= 90.0:
				nydus_spawn_timer = 0.0
				var crater_idx := randi() % 12
				nydus_crater_manager.trigger_crater_awakening(crater_idx, spawners_destroyed_count)


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


func _get_swarm_archetype_id(type_name: Variant) -> int:
	if type_name is int:
		return type_name
	var s: String = str(type_name).to_lower()
	match s:
		"zergling":
			return 0
		"roach":
			return 1
		"baneling":
			return 2
		"hydralisk", "hydra":
			return 3
	return 0


func _on_drop_pod_landed(target_position: Vector3, _units_spawned: Array = []) -> void:
	if swarm_simulation:
		swarm_simulation.spawn_wave(0, 4, target_position, 2.5) # Zergling
		swarm_simulation.spawn_wave(1, 2, target_position, 3.0) # Roach
	if combat_vfx_pool and combat_vfx_pool.has_method("spawn_acid_burst"):
		combat_vfx_pool.spawn_acid_burst(target_position)
	_play_sfx_3d(&"baneling_explode", target_position)


func _on_scheduled_attack_warning(wave_index: int, leader_name: String, seconds_left: float, dir: Vector3) -> void:
	if SignalBus.has_signal("scheduled_attack_warned"):
		SignalBus.scheduled_attack_warned.emit(wave_index, leader_name, seconds_left, dir)


func _on_scheduled_attack_dispatched(wave_index: int, leader_data: Dictionary, hive_pos: Vector3, _base_pos: Vector3) -> void:
	if SignalBus.has_signal("scheduled_attack_started"):
		SignalBus.scheduled_attack_started.emit(wave_index, leader_data)
	if state_label:
		state_label.text = "¡ASALTO DE LA COLMENA: %s EN CAMINO!" % leader_data.get("leader_name", "Líder")
		state_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
	if SFXM and SFXM.instance != null:
		SFXM.instance.play_voice_alert(&"wave_incoming")

	# Spawn escort swarm wave
	if swarm_simulation:
		var escort_type: Variant = leader_data.get("escort_type", &"zergling")
		var escort_arch_id: int = _get_swarm_archetype_id(escort_type)
		var escort_count: int = leader_data.get("escort_count", 8)
		swarm_simulation.spawn_wave(escort_arch_id, escort_count, hive_pos, 4.0)

	# Spawn Leader Boss (Brutalisk or Hybrid Dominator scaled by leader_data)
	var boss: CharacterBody3D = null
	if wave_index % 2 == 0:
		boss = BossHybrid3D.new()
	else:
		boss = BossBrutalisk3D.new()

	boss.global_position = hive_pos
	boss.max_health = float(leader_data.get("hp", 4000.0))
	boss.current_health = boss.max_health
	boss.flat_armor = float(leader_data.get("armor", 8.0))
	boss.attack_damage = float(leader_data.get("damage", 50.0))
	boss.boss_name = leader_data.get("leader_name", "Líder de Asalto")
	add_child(boss)

	if boss_health_bar_ui:
		var shields: float = boss.max_shields if "max_shields" in boss else 0.0
		boss_health_bar_ui.track_boss(boss, boss.boss_name, boss.max_health, shields)


func _on_nydus_tremor_started(crater_index: int, pos: Vector3, _delay: float) -> void:
	var tier_data: Dictionary = timed_schedule.get_nydus_tier(spawners_destroyed_count)
	var tier_name: String = tier_data.get("tier_name", "Nydus Worm")
	if SignalBus.has_signal("nydus_tremor_alert"):
		SignalBus.nydus_tremor_alert.emit(crater_index, pos, tier_name)


func _on_nydus_emerged(_crater_index: int, pos: Vector3, nydus_data: Dictionary) -> void:
	var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
	if SFXM and SFXM.instance != null:
		SFXM.instance.play_voice_alert(&"wave_incoming")

	var nydus := BossNydus3D.new()
	nydus.global_position = pos
	nydus.max_health = float(nydus_data.get("max_health", 8000.0))
	nydus.current_health = nydus.max_health
	nydus.kill_reward = int(nydus_data.get("bounty", 2500))
	add_child(nydus)
	if boss_health_bar_ui:
		var tier_name: String = nydus_data.get("tier_name", "Gusano Nydus")
		boss_health_bar_ui.track_boss(nydus, tier_name, nydus.max_health, 0.0)



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			_toggle_debug_telemetry()
		elif event.ctrl_pressed and event.alt_pressed and event.keycode == KEY_C:
			_toggle_debug_cli_modal()
		elif debug_cli_layer and debug_cli_layer.visible and event.keycode == KEY_ESCAPE:
			_toggle_debug_cli_modal()
		elif event.keycode == KEY_ESCAPE or event.keycode == KEY_F10:
			toggle_settings_modal()


func _setup_debug_console() -> void:
	if debug_console == null:
		debug_console = DebugConsole.new(economy_manager, story_phase_manager, active_hero)


func _toggle_debug_cli_modal() -> void:
	if debug_cli_layer == null:
		_build_debug_cli_modal()
	debug_cli_layer.visible = not debug_cli_layer.visible
	if debug_cli_layer.visible and debug_cli_input:
		debug_cli_input.grab_focus()


func _build_debug_cli_modal() -> void:
	debug_cli_layer = CanvasLayer.new()
	debug_cli_layer.name = "DebugCLILayer"
	debug_cli_layer.layer = 120
	add_child(debug_cli_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.15
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.15
	panel.offset_left = -280.0
	panel.offset_top = 0.0
	panel.offset_right = 280.0
	panel.offset_bottom = 120.0
	panel.custom_minimum_size = Vector2(560, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.95)
	style.border_color = Color(0.2, 0.8, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	debug_cli_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "★ SFE5 DEVELOPER DEBUG CONSOLE (Ctrl+Alt+C) ★"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(title)

	debug_cli_input = LineEdit.new()
	debug_cli_input.placeholder_text = "Comandos: give 50000 | kill | god | phase 2 | tp 0 0 | help"
	debug_cli_input.text_submitted.connect(_on_debug_cli_submitted)
	vbox.add_child(debug_cli_input)

	debug_cli_output = Label.new()
	debug_cli_output.text = "Escribe un comando y pulsa ENTER."
	debug_cli_output.add_theme_font_size_override("font_size", 11)
	debug_cli_output.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(debug_cli_output)


func _on_debug_cli_submitted(raw_cmd: String) -> void:
	if debug_console == null:
		_setup_debug_console()
	debug_console.economy_manager = economy_manager
	debug_console.story_phase_manager = story_phase_manager
	debug_console.active_hero = active_hero

	var res: String = debug_console.execute_command_string(raw_cmd)
	if debug_cli_output:
		debug_cli_output.text = res
	if debug_cli_input:
		debug_cli_input.clear()


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
	var chosen_mode: StringName = start_modal.selected_mode_id if start_modal else &"classic"

	# Load ModeData & GameModeManager (Task 11.1)
	var mode_res_path: String = "res://data/modes/%s.tres" % str(chosen_mode)
	var mode_data: ModeData = null
	if ResourceLoader.exists(mode_res_path):
		mode_data = load(mode_res_path) as ModeData
	game_mode_manager = GameModeManager.new(mode_data)

	# 1. Mode Torment: Force Torment difficulty (Task 11.2)
	if chosen_mode == &"torment":
		diff_tier = 4

	# Apply difficulty scaling
	if difficulty_manager:
		difficulty_manager.set_difficulty(diff_tier)
	elif SFEDifficultyManager.instance:
		SFEDifficultyManager.set_difficulty(diff_tier)

	# 2. Configure Game Mode & GameSession
	var sess := _get_game_session()
	if sess and sess.has_method("set_game_mode"):
		sess.set_game_mode(chosen_mode)
	elif sess:
		sess.active_mode = mode_data

	if sess:
		sess.set_meta("is_random_selected", is_random)
		if chosen_mode == &"split_income":
			sess.split_income_mode = true

	# 3. Start GameSession and calculate initial minerals per SFE5 wiki rules
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
		if chosen_mode == &"split_income" and "split_income" in economy_manager:
			economy_manager.split_income = true

	# 4. Setup Story Phase Manager (Fase 9: Zerg -> Protoss 1 -> Protoss 2 -> Jefes Cúspide)
	if story_phase_manager == null:
		story_phase_manager = StoryPhaseManager.new(6, 4)
		if not story_phase_manager.phase_changed.is_connected(_on_story_phase_changed):
			story_phase_manager.phase_changed.connect(_on_story_phase_changed)

	# Mode Hardcore: disable buff purchases in PlayerConsole, disable Protoss phases, deploy starting roster
	if chosen_mode == &"hardcore":
		story_phase_manager.allow_protoss_phases = false
		if player_console:
			player_console.allow_buff_purchase = false
		var rally_origin: Vector3 = command_center.global_position + Vector3(5.0, 0.0, 0.0) if command_center else Vector3(-20.0, 0.0, 24.0)
		_spawn_hardcore_starting_roster(game_mode_manager.get_hardcore_starting_roster(), rally_origin)

	# Mode Nightmare: cyclical wave progression wire
	if chosen_mode == &"nightmare":
		game_mode_manager.nightmare_level_updated.connect(func(lvl: int, slot: int):
			if sc2_hud_root:
				var t_name: String = GameModeManager.NIGHTMARE_CYCLE_TYPES[slot - 1] if slot <= GameModeManager.NIGHTMARE_CYCLE_TYPES.size() else "Élite"
				sc2_hud_root.update_nightmare_status(lvl, slot, t_name)
			if lvl >= 2:
				AchievementSystem.unlock_achievement(&"ach_nightmare_survivor")
		)
		var first_wave_desc := game_mode_manager.advance_nightmare_wave()
		if sc2_hud_root:
			sc2_hud_root.update_nightmare_status(first_wave_desc.get("level", 1), first_wave_desc.get("cycle_slot", 1), first_wave_desc.get("type", ""))

	# Mode Mutation: spawner speed +35%, enemy HP/dmg +25%, mineral bounty +25%
	if chosen_mode == &"mutation":
		_apply_mutation_mode_multipliers()

	var bounty_rate: int = 50
	if economy_manager and "bounty_per_kill" in economy_manager:
		bounty_rate = economy_manager.bounty_per_kill
	elif sess and "active_mode" in sess and sess.active_mode and "mineral_bounty_mult" in sess.active_mode:
		bounty_rate = int(50 * sess.active_mode.mineral_bounty_mult)

	# 5. Bind Selected Hero Data & Visuals
	if selected_hero and active_hero:
		active_hero.hero_data = selected_hero
		active_hero.spawn_position = active_hero.global_position
		active_hero.swarm_simulation = swarm_simulation
		if debug_console:
			debug_console.active_hero = active_hero
			debug_console.story_phase_manager = story_phase_manager
			debug_console.economy_manager = economy_manager
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
			if chosen_mode == &"torment" and active_hero.current_difficulty_data:
				active_hero.current_difficulty_data.permadeath = true

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

	# 6. Update SC2 Top Bar
	if sc2_hud_root:
		var current_seed: int = sess.map_seed if sess and "map_seed" in sess and sess.map_seed != 0 else 12345
		sc2_hud_root.update_seed(current_seed)
		if pedestal_puzzle:
			pedestal_puzzle.setup_deterministic_initial_state(current_seed)
		sc2_hud_root.update_difficulty(SFEDifficultyManager.get_difficulty_name(), diff_tier)
		_refresh_phase_hud()
		if economy_manager:
			sc2_hud_root.update_minerals(economy_manager.current_minerals)
		sc2_hud_root.update_supply(1, max_sup)
		sc2_hud_root.top_wave_label.text = "¡OLEADA ENTRANTE EN 5s!"
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	start_modal = null

	# SFE5 Gameplay Loop Activation (Task 3.9)
	is_waves_mode = false
	if sess and "active_mode" in sess and sess.active_mode and "use_waves_mode" in sess.active_mode:
		is_waves_mode = sess.active_mode.use_waves_mode

	if not is_waves_mode:
		if start_wave_btn:
			start_wave_btn.visible = false
		var wp := get_node_or_null("UI/WavePanel")
		if wp:
			wp.visible = false

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
					first_spawner._try_spawn_cycle()
				_refresh_phase_hud()


func _spawn_hardcore_starting_roster(roster: Array[Dictionary], origin: Vector3) -> void:
	var angle_step: float = TAU / 12.0
	var current_idx: int = 0
	for entry in roster:
		var u_type: String = str(entry.get("type", "marine"))
		var count: int = int(entry.get("count", 1))
		for _c in range(count):
			var offset := Vector3(cos(current_idx * angle_step), 0.0, sin(current_idx * angle_step)) * 5.0
			var spawn_pos := origin + offset
			var unit := BaseUnit3D.new()
			unit.name = "%s_elite_%d" % [u_type.capitalize(), current_idx + 1]
			unit.position = spawn_pos
			match u_type:
				"marine":
					unit.max_health = 45.0
					unit.attack_damage = 7.0
					unit.attack_cooldown = 0.6
					unit.attack_range = 10.0
					unit.move_speed = 5.0
				"marauder":
					unit.max_health = 125.0
					unit.attack_damage = 10.0
					unit.attack_cooldown = 1.0
					unit.attack_range = 6.0
					unit.move_speed = 4.8
				"zealot":
					unit.max_health = 160.0
					unit.attack_damage = 16.0
					unit.attack_cooldown = 0.8
					unit.attack_range = 2.0
					unit.move_speed = 5.2
				"stalker":
					unit.max_health = 160.0
					unit.attack_damage = 13.0
					unit.attack_cooldown = 1.0
					unit.attack_range = 7.0
					unit.move_speed = 5.5
				"zergling":
					unit.max_health = 35.0
					unit.attack_damage = 5.0
					unit.attack_cooldown = 0.5
					unit.attack_range = 1.5
					unit.move_speed = 6.0
				"roach":
					unit.max_health = 145.0
					unit.attack_damage = 16.0
					unit.attack_cooldown = 1.4
					unit.attack_range = 4.0
					unit.move_speed = 4.5
			unit.current_health = unit.max_health
			unit.add_to_group("allies")
			if unit.has_method("promote_to_elite"):
				unit.promote_to_elite()
			elif unit.has_node("EliteComponent"):
				var el = unit.get_node("EliteComponent")
				if el.has_method("promote_to_elite"):
					el.promote_to_elite()
			else:
				unit.set_meta("is_elite", true)
			add_child(unit)
			current_idx += 1


func _apply_mutation_mode_multipliers() -> void:
	SFEDifficultyManager.enemy_health_multiplier *= 1.25
	SFEDifficultyManager.enemy_damage_multiplier *= 1.25
	if economy_manager:
		economy_manager.bounty_per_kill = int(economy_manager.bounty_per_kill * 1.25)
	if is_inside_tree():
		for sp in get_tree().get_nodes_in_group("spawners"):
			if sp is SpawnerNode:
				sp.cycle_seconds = maxf(1.0, sp.cycle_seconds / 1.35)
				sp.max_health *= 1.25
				sp.current_health = sp.max_health


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
	var seed_val: int = 0
	if sess and "map_seed" in sess and sess.map_seed != 0:
		seed_val = sess.map_seed
	else:
		var cli_seed := GameSession.parse_cli_seed() if GameSession != null else 0
		if cli_seed != 0:
			seed_val = cli_seed
		else:
			seed_val = GameConfigScript.DEFAULT_SEED
			push_warning("main_level: No active GameSession map_seed found, using fallback seed %d" % seed_val)
	var map_seed := MapSeed.new(seed_val)
	map_generator = MapGenerator.new(map_seed)
	
	var spawner_count: int = GameConfigScript.SPAWNER_COUNT_DEFAULT
	var layout_plan := map_generator.generate_layout_plan(spawner_count)
	spawner_chain = map_generator.spawn_spawner_chain(self, layout_plan, budget_manager, swarm_simulation)
	
	spawner_chain.spawner_unlocked.connect(_on_spawner_unlocked)
	spawner_chain.spawner_chain_step_completed.connect(_on_spawner_step_completed)
	spawner_chain.all_spawners_destroyed.connect(_on_all_spawners_cleared)
	if sc2_hud_root:
		sc2_hud_root.update_seed(seed_val)
	_update_spawner_minimap()


func _update_spawner_minimap() -> void:
	if not sc2_hud_root or not spawner_chain:
		return
	var markers: Array = []
	for sp in spawner_chain.spawners:
		if is_instance_valid(sp):
			markers.append({
				"position": sp.global_position,
				"state": sp.current_state
			})
	sc2_hud_root.update_spawner_markers(markers)


func _on_spawner_unlocked(spawner: SpawnerNode) -> void:
	_update_spawner_minimap()
	if sc2_hud_root and sc2_hud_root.top_wave_label:
		sc2_hud_root.top_wave_label.text = "¡OBJETIVO: DESTRUYE %s!" % spawner.spawner_name.to_upper()
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))


func _on_spawner_step_completed(_sid: StringName, remaining: int) -> void:
	spawners_destroyed_count += 1
	if tutorial_manager:
		tutorial_manager.record_spawner_destroyed()
	if spawners_destroyed_count >= 3 and match_timer < 300.0:
		AchievementSystem.unlock_achievement(&"ach_speedrunner")
	var race: StringName = &"zerg"
	if story_phase_manager and story_phase_manager.current_phase == StoryPhaseManager.StoryPhase.PROTOSS_1:
		race = &"protoss"
	if story_phase_manager:
		story_phase_manager.report_spawner_cleared(race)
	_update_spawner_minimap()
	_refresh_phase_hud()
	if sc2_hud_root and sc2_hud_root.top_wave_label:
		if remaining > 0:
			sc2_hud_root.top_wave_label.text = "¡OBJETIVO DESTRUIDO! Quedan %d engendradores." % remaining
			sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			sc2_hud_root.top_wave_label.text = "¡CADENA DE ENGENDRADORES PURGADA!"
			sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))


func _refresh_phase_hud() -> void:
	if not sc2_hud_root or not story_phase_manager:
		return
	var status_text: String = story_phase_manager.get_phase_header_status()
	var bounty_rate: int = 50
	if economy_manager and "bounty_per_kill" in economy_manager:
		bounty_rate = economy_manager.bounty_per_kill
	sc2_hud_root.update_story_phase(status_text, bounty_rate)


func _on_story_phase_changed(_old_phase: int, new_phase: int, phase_title: String, announcement: String) -> void:
	if story_phase_manager:
		var ambient_color: Color = story_phase_manager.get_ambient_lighting_color(new_phase)
		var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
		if env_node and env_node.environment:
			env_node.environment.ambient_light_color = ambient_color
		var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if sun:
			sun.light_color = ambient_color

	if new_phase == StoryPhaseManager.StoryPhase.PROTOSS_1 and nydus_crater_manager:
		nydus_crater_manager.activate_network()
		nydus_spawn_timer = 85.0 # Emerge first Nydus quickly (in 5s)

	_refresh_phase_hud()
	if sc2_hud_root and sc2_hud_root.top_wave_label:
		sc2_hud_root.top_wave_label.text = "¡%s!" % announcement.to_upper()
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))


func _setup_protoss_spawner_network() -> void:
	var protoss_slots: Array[Vector3] = [
		Vector3(-24.0, 0.0, -22.0),
		Vector3(0.0, 0.0, -26.0),
		Vector3(24.0, 0.0, -20.0),
		Vector3(20.0, 0.0, 10.0)
	]
	var protoss_spawners: Array[SpawnerNode] = []
	for i in range(4):
		var p_spawner := SpawnerNode.new()
		p_spawner.spawner_id = StringName("protoss_warp_%02d" % (i + 1))
		p_spawner.spawner_name = "Portal Warp Protoss #%d" % (i + 1)
		p_spawner.family = "protoss"
		p_spawner.group_size = 5
		p_spawner.cycle_seconds = 18.0
		p_spawner.max_health = 4000.0
		p_spawner.structure_armor = 12.0
		p_spawner.archetype_id = 3 # Stalker / Hydra
		p_spawner.position = protoss_slots[i]
		p_spawner.budget_manager = budget_manager
		p_spawner.swarm_simulation = swarm_simulation
		p_spawner.initial_state = SpawnerNode.State.LOCKED
		add_child(p_spawner)

		# Protoss Gold / Cyan Visual Theme
		if p_spawner.visual_mesh:
			for child in p_spawner.visual_mesh.get_children():
				if child is MeshInstance3D:
					var p_mat := StandardMaterial3D.new()
					p_mat.albedo_color = Color(0.9, 0.75, 0.2)
					p_mat.metallic = 0.85
					p_mat.roughness = 0.25
					p_mat.emission_enabled = true
					p_mat.emission = Color(0.1, 0.7, 1.0) * 0.9
					(child as MeshInstance3D).material_override = p_mat

		protoss_spawners.append(p_spawner)

	spawner_chain = SpawnerChain.new()
	spawner_chain.set_simulation(swarm_simulation)
	var prev_id: StringName = &""
	for sp in protoss_spawners:
		spawner_chain.register_spawner(sp, prev_id)
		prev_id = sp.spawner_id

	spawner_chain.spawner_unlocked.connect(_on_spawner_unlocked)
	spawner_chain.spawner_chain_step_completed.connect(_on_spawner_step_completed)
	spawner_chain.all_spawners_destroyed.connect(_on_all_spawners_cleared)
	
	if protoss_spawners.size() > 0:
		protoss_spawners[0].unlock()
	_update_spawner_minimap()


func _spawn_xelnaga_crystals() -> void:
	var crystal_positions: Array[Vector3] = [
		Vector3(-20.0, 0.0, -18.0),
		Vector3(20.0, 0.0, -20.0),
		Vector3(6.0, 0.0, 12.0)
	]
	xelnaga_crystals.clear()
	for i in range(3):
		var crystal_pos: Vector3 = crystal_positions[i]
		var crystal := XelNagaCrystal3D.new()
		crystal.name = "XelNagaCrystal_%d" % (i + 1)
		crystal.position = crystal_pos
		crystal.crystal_index = i
		crystal.main_level_ref = self
		crystal.add_to_group("enemies")
		crystal.add_to_group("structures")
		crystal.add_to_group("xelnaga_crystals")

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 4.5, 3.0)
		col.shape = box
		col.position = Vector3(0.0, 2.25, 0.0)
		crystal.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.2
		prism.bottom_radius = 1.4
		prism.height = 4.5
		mesh_inst.mesh = prism
		mesh_inst.position = Vector3(0.0, 2.25, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.85, 0.35)
		mat.roughness = 0.2
		mat.metallic = 0.5
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.5) * 0.8
		mesh_inst.material_override = mat
		crystal.add_child(mesh_inst)

		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0.0, 5.0, 0.0)
		lbl.font_size = 26
		lbl.modulate = Color(0.3, 1.0, 0.5)
		lbl.text = "💎 CRISTAL XEL'NAGA #%d\n[5000 HP]" % (i + 1)
		crystal.add_child(lbl)

		add_child(crystal)
		xelnaga_crystals.append(crystal)

		# Spawn Guardian Boss for each crystal
		var guardian := BossHybrid3D.new()
		guardian.position = crystal_pos + Vector3(3.0, 0.0, 3.0)
		guardian.boss_name = "Guardián Híbrido #%d" % (i + 1)
		guardian.max_health = 6000.0
		guardian.current_health = 6000.0
		add_child(guardian)
		if boss_health_bar_ui:
			boss_health_bar_ui.bind_boss(guardian)

	if SignalBus.has_signal("announcement_triggered"):
		SignalBus.announcement_triggered.emit("¡Fase 3: Armoniza los 3 Cristales Xel'Naga!")


func _on_xelnaga_crystal_harmonized(crystal_index: int) -> void:
	if story_phase_manager:
		story_phase_manager.harmonize_xelnaga_crystal(crystal_index)
	_play_sfx_3d(&"upgrade_complete", Vector3(0.0, 0.0, 0.0))
	_refresh_phase_hud()
	if story_phase_manager and story_phase_manager.current_phase == StoryPhaseManager.StoryPhase.PINNACLE_BOSSES:
		_spawn_final_pinnacle_boss()


func _spawn_final_pinnacle_boss() -> void:
	if final_pinnacle_boss and is_instance_valid(final_pinnacle_boss):
		return
	var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
	if SFXM and SFXM.instance != null:
		SFXM.instance.play_voice_alert(&"wave_incoming")
	var boss := BossHybrid3D.new()
	boss.name = "FinalBossNarud"
	boss.boss_name = "Narud / Hybrid Behemoth"
	boss.max_health = 25000.0
	boss.current_health = 25000.0
	boss.max_shields = 5000.0
	boss.current_shields = 5000.0
	boss.flat_armor = 14.0
	boss.attack_damage = 110.0
	boss.position = Vector3(0.0, 0.0, -30.0)
	add_child(boss)
	final_pinnacle_boss = boss

	if boss_health_bar_ui:
		boss_health_bar_ui.bind_boss(boss)

	boss.boss_died.connect(func():
		_end_game(true)
	)

	# Elite Escort Wave
	if swarm_simulation:
		swarm_simulation.spawn_wave(1, 8, Vector3(0.0, 0.0, -28.0), 5.0) # Roaches
		swarm_simulation.spawn_wave(3, 6, Vector3(0.0, 0.0, -32.0), 5.0) # Hydralisks

	if sc2_hud_root and sc2_hud_root.top_wave_label:
		sc2_hud_root.top_wave_label.text = "¡FASE 4/4: DERROTA AL JEFE CÚSPIDE NARUD!"
		sc2_hud_root.top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))


func _spawn_map_secrets() -> void:
	var sess := _get_game_session()
	var seed_val: int = sess.map_seed if sess and "map_seed" in sess and sess.map_seed != 0 else 12345
	secret_manager = SecretManager.new(seed_val)

	# 1. Outhouse (+10 supply)
	_outhouse_node = Outhouse3D.new()
	_outhouse_node.name = "SecretOuthouse"
	_outhouse_node.position = Vector3(-35.0, 0.0, 20.0)
	_outhouse_node.main_level_ref = self
	_outhouse_node.add_to_group("structures")
	_outhouse_node.add_to_group("secrets")

	var o_col := CollisionShape3D.new()
	var o_box := BoxShape3D.new()
	o_box.size = Vector3(2.5, 3.0, 2.5)
	o_col.shape = o_box
	o_col.position = Vector3(0.0, 1.5, 0.0)
	_outhouse_node.add_child(o_col)

	var o_mesh := MeshInstance3D.new()
	var o_box_mesh := BoxMesh.new()
	o_box_mesh.size = Vector3(2.2, 2.8, 2.2)
	o_mesh.mesh = o_box_mesh
	o_mesh.position = Vector3(0.0, 1.4, 0.0)
	var o_mat := StandardMaterial3D.new()
	o_mat.albedo_color = Color(0.45, 0.32, 0.18)
	o_mesh.material_override = o_mat
	_outhouse_node.add_child(o_mesh)

	var o_lbl := Label3D.new()
	o_lbl.name = "Label3D"
	o_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	o_lbl.position = Vector3(0.0, 3.6, 0.0)
	o_lbl.font_size = 22
	o_lbl.modulate = Color(0.3, 0.9, 0.4)
	o_lbl.text = "⛺ REFUGIO SECRETO\n[+10 Suministro]"
	_outhouse_node.add_child(o_lbl)
	add_child(_outhouse_node)

	# 2. Mystery Boxes (4 items)
	_mystery_box_nodes.clear()
	for i in range(SecretManager.MYSTERY_BOX_CANDIDATE_POINTS.size()):
		var b_pos: Vector3 = SecretManager.MYSTERY_BOX_CANDIDATE_POINTS[i]
		var box := MysteryBox3D.new()
		box.name = "MysteryBox_%d" % (i + 1)
		box.position = b_pos
		box.box_index = i
		box.main_level_ref = self
		box.add_to_group("structures")
		box.add_to_group("secrets")
		box.add_to_group("mystery_boxes")

		var b_col := CollisionShape3D.new()
		var b_shape := BoxShape3D.new()
		b_shape.size = Vector3(1.5, 1.5, 1.5)
		b_col.shape = b_shape
		b_col.position = Vector3(0.0, 0.75, 0.0)
		box.add_child(b_col)

		var b_mesh := MeshInstance3D.new()
		var b_box_m := BoxMesh.new()
		b_box_m.size = Vector3(1.2, 1.2, 1.2)
		b_mesh.mesh = b_box_m
		b_mesh.position = Vector3(0.0, 0.6, 0.0)
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.85, 0.65, 0.15)
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 0.8, 0.2) * 0.5
		b_mesh.material_override = b_mat
		box.add_child(b_mesh)

		var b_lbl := Label3D.new()
		b_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b_lbl.position = Vector3(0.0, 1.8, 0.0)
		b_lbl.font_size = 20
		b_lbl.modulate = Color(1.0, 0.85, 0.2)
		b_lbl.text = "[?] CAJA SORPRESA"
		box.add_child(b_lbl)

		add_child(box)
		_mystery_box_nodes.append(box)

	# 3. Lucky Lizard (awards 3000 minerals)
	_lucky_lizard_node = LuckyLizard3D.new()
	_lucky_lizard_node.name = "LuckyLizard"
	_lucky_lizard_node.position = Vector3(32.0, 0.0, 0.0)
	_lucky_lizard_node.main_level_ref = self
	_lucky_lizard_node.add_to_group("enemies")
	_lucky_lizard_node.add_to_group("secrets")

	var l_col := CollisionShape3D.new()
	var l_cap := CapsuleShape3D.new()
	l_cap.radius = 0.4
	l_cap.height = 1.0
	l_col.shape = l_cap
	l_col.position = Vector3(0.0, 0.5, 0.0)
	_lucky_lizard_node.add_child(l_col)

	var l_mesh := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 0.35
	l_cyl.bottom_radius = 0.4
	l_cyl.height = 0.8
	l_mesh.mesh = l_cyl
	l_mesh.position = Vector3(0.0, 0.4, 0.0)
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = Color(0.2, 0.9, 0.3)
	l_mat.emission_enabled = true
	l_mat.emission = Color(0.5, 1.0, 0.3) * 0.6
	l_mesh.material_override = l_mat
	_lucky_lizard_node.add_child(l_mesh)

	var l_lbl := Label3D.new()
	l_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l_lbl.position = Vector3(0.0, 1.4, 0.0)
	l_lbl.font_size = 22
	l_lbl.modulate = Color(0.3, 1.0, 0.4)
	l_lbl.text = "🦎 LAGARTO DE LA SUERTE\n[+3.000 Minerales]"
	_lucky_lizard_node.add_child(l_lbl)
	add_child(_lucky_lizard_node)

	# 4. Fueling Station (awards 4000 minerals, ach_fueling_up)
	_fueling_station_node = FuelingStation3D.new()
	_fueling_station_node.name = "FuelingStation"
	_fueling_station_node.position = Vector3(18.0, 0.0, 30.0)
	_fueling_station_node.main_level_ref = self
	_fueling_station_node.add_to_group("structures")
	_fueling_station_node.add_to_group("secrets")

	var f_col := CollisionShape3D.new()
	var f_cyl_col := CylinderShape3D.new()
	f_cyl_col.radius = 2.0
	f_cyl_col.height = 3.0
	f_col.shape = f_cyl_col
	f_col.position = Vector3(0.0, 1.5, 0.0)
	_fueling_station_node.add_child(f_col)

	var f_mesh := MeshInstance3D.new()
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 1.6
	f_cyl.bottom_radius = 1.8
	f_cyl.height = 2.6
	f_mesh.mesh = f_cyl
	f_mesh.position = Vector3(0.0, 1.3, 0.0)

	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.85, 0.55, 0.1)
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.7, 0.1) * 0.5
	f_mesh.material_override = f_mat
	_fueling_station_node.add_child(f_mesh)

	var f_lbl := Label3D.new()
	f_lbl.name = "Label3D"
	f_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f_lbl.position = Vector3(0.0, 3.4, 0.0)
	f_lbl.font_size = 22
	f_lbl.modulate = Color(1.0, 0.8, 0.2)
	f_lbl.text = "⛽ ESTACIÓN DE COMBUSTIBLE\n[Permanece 5s para repostar]"
	_fueling_station_node.add_child(f_lbl)
	add_child(_fueling_station_node)


func _check_secret_proximities(delta: float = 0.0) -> void:
	if not active_hero or not is_instance_valid(active_hero) or not secret_manager:
		return
	var hero_pos: Vector3 = active_hero.global_position

	# Check Outhouse Proximity
	if _outhouse_node and is_instance_valid(_outhouse_node) and not secret_manager.outhouse_unlocked:
		if hero_pos.distance_to(_outhouse_node.global_position) <= 4.0:
			_trigger_outhouse_interaction(_outhouse_node)

	# Check Mystery Boxes Proximity
	for i in range(_mystery_box_nodes.size()):
		var box: Node3D = _mystery_box_nodes[i]
		if box and is_instance_valid(box) and not secret_manager.boxes_opened.has(i):
			if hero_pos.distance_to(box.global_position) <= 3.0:
				_trigger_mystery_box_interaction(box, i)

	# Check Fueling Station Proximity (5s hold time)
	if _fueling_station_node and is_instance_valid(_fueling_station_node) and not secret_manager.fueling_completed:
		if hero_pos.distance_to(_fueling_station_node.global_position) <= 4.5:
			_fueling_hold_timer += delta
			var pct: int = mini(100, int((_fueling_hold_timer / 5.0) * 100))
			var f_lbl: Label3D = _fueling_station_node.get_node_or_null("Label3D") as Label3D
			if f_lbl:
				f_lbl.text = "⛽ ESTACIÓN DE COMBUSTIBLE\nRepostando: %d%%" % pct
			if _fueling_hold_timer >= 5.0:
				_trigger_fueling_station_complete(_fueling_station_node)
		else:
			if _fueling_hold_timer > 0.0:
				_fueling_hold_timer = 0.0
				var f_lbl: Label3D = _fueling_station_node.get_node_or_null("Label3D") as Label3D
				if f_lbl and not secret_manager.fueling_completed:
					f_lbl.text = "⛽ ESTACIÓN DE COMBUSTIBLE\n[Permanece 5s para repostar]"


func _trigger_outhouse_interaction(node: Node3D) -> void:
	if not secret_manager or secret_manager.outhouse_unlocked:
		return
	var sess := _get_game_session()
	var ok := secret_manager.trigger_outhouse_secret(sess)
	if ok:
		_play_sfx_3d(&"upgrade_complete", node.global_position)
		FloatingTextManager.spawn_text(self, node.global_position + Vector3(0.0, 3.5, 0.0), "+10 SUMINISTRO MÁXIMO!", Color(0.2, 1.0, 0.4))
		if sc2_hud_root:
			var cur_sup: int = player_console._get_current_supply() if player_console else 1
			var max_sup: int = (sess.get_max_supply() if sess else 80) + 10
			sc2_hud_root.update_supply(cur_sup, max_sup)
		var lbl: Label3D = node.get_node_or_null("Label3D") as Label3D
		if lbl:
			lbl.text = "🔓 REFUGIO DESBLOQUEADO (+10 Suministro)"
			lbl.modulate = Color(0.4, 1.0, 0.4)


func _trigger_mystery_box_interaction(node: Node3D, idx: int) -> void:
	if not secret_manager or secret_manager.boxes_opened.has(idx):
		return
	var loot := secret_manager.open_mystery_box(idx)
	if not loot.is_empty():
		_play_sfx_3d(&"upgrade_complete", node.global_position)
		FloatingTextManager.spawn_text(self, node.global_position + Vector3(0.0, 2.0, 0.0), str(loot.get("label", "Botín")), Color(1.0, 0.85, 0.2))
		match str(loot.get("type", "")):
			"minerals":
				if economy_manager:
					economy_manager.add_minerals(int(loot.get("amount", 1500)), "Mystery Box")
			"shield_buff":
				if active_hero and active_hero.hero_data:
					active_hero.hero_data.current_shield = minf(active_hero.hero_data.max_shield, active_hero.hero_data.current_shield + float(loot.get("amount", 250.0)))
			"experience":
				if active_hero:
					active_hero.gain_experience(int(loot.get("amount", 2000)))
		node.queue_free()


func _trigger_lucky_lizard_death(lizard: Node3D) -> void:
	if not secret_manager or secret_manager.lizard_caught:
		return
	var reward := secret_manager.trigger_lucky_lizard()
	if reward > 0:
		_play_sfx_3d(&"zerg_death", lizard.global_position)
		FloatingTextManager.spawn_text(self, lizard.global_position + Vector3(0.0, 2.0, 0.0), "+%d MINERALES (LAGARTO DE LA SUERTE)" % reward, Color(1.0, 0.85, 0.2))
		if economy_manager:
			economy_manager.add_minerals(reward, "Lucky Lizard")
		session_kills += 1
		if active_hero:
			active_hero.gain_experience(1000)
		lizard.queue_free()


func _trigger_fueling_station_complete(node: Node3D) -> void:
	if not secret_manager or secret_manager.fueling_completed:
		return
	var reward: int = secret_manager.complete_fueling_station()
	if reward <= 0:
		reward = 4000
	_play_sfx_3d(&"upgrade_complete", node.global_position)
	FloatingTextManager.spawn_text(self, node.global_position + Vector3(0.0, 3.0, 0.0), "+4000 MINERALES (ESTACIÓN REPOSTADA)", Color(0.2, 1.0, 0.4))
	if economy_manager:
		economy_manager.add_minerals(reward, "Fueling Station Completed")
	AchievementSystem.unlock_achievement(&"ach_fueling_up")
	var lbl: Label3D = node.get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.text = "⛽ ESTACIÓN DE COMBUSTIBLE\n[REPOSTE COMPLETO: +4000 💎]"
		lbl.modulate = Color(0.2, 1.0, 0.5)


func _process_altars_and_teleports(delta: float) -> void:
	if _teleport_cooldown > 0.0:
		_teleport_cooldown = maxf(0.0, _teleport_cooldown - delta)

	if not active_hero or not is_instance_valid(active_hero):
		return
	var hero_pos: Vector3 = active_hero.global_position

	# 1. Forward Bridge Pad unlock check (approaching with 500 minerals)
	if _forward_bridge_pad and is_instance_valid(_forward_bridge_pad) and not _is_forward_bridge_unlocked:
		if hero_pos.distance_to(_forward_bridge_pad.global_position) <= 3.5:
			if economy_manager and economy_manager.current_minerals >= 500:
				economy_manager.spend_minerals(500, "Forward Bridge Pad Unlock")
				_unlock_forward_bridge()

	# 2. Gorgon Altar hold-zone timer (5s)
	if _pinnacle_altar_gorgon and is_instance_valid(_pinnacle_altar_gorgon):
		var altar_gorgon_completed: bool = _pinnacle_altar_gorgon.get_meta("is_completed", false)
		if not altar_gorgon_completed:
			if hero_pos.distance_to(_pinnacle_altar_gorgon.global_position) <= 4.5:
				_gorgon_hold_timer += delta
				var pct: int = mini(100, int((_gorgon_hold_timer / 5.0) * 100))
				var g_lbl: Label3D = _pinnacle_altar_gorgon.get_node_or_null("Label3D") as Label3D
				if g_lbl:
					g_lbl.text = "ALTAR DE INVOCACIÓN: GORGON (ANTENA SR-04)\nSintonizando: %d%%" % pct
				if _gorgon_hold_timer >= 5.0:
					_pinnacle_altar_gorgon.set_meta("is_completed", true)
					if g_lbl:
						g_lbl.text = "ANTENA SR-04\n[¡GORGON INVOCADO!]"
					_spawn_pinnacle_boss(&"gorgon", Vector3(30.0, 0.0, 30.0))
			else:
				if _gorgon_hold_timer > 0.0:
					_gorgon_hold_timer = 0.0
					var g_lbl: Label3D = _pinnacle_altar_gorgon.get_node_or_null("Label3D") as Label3D
					if g_lbl and not altar_gorgon_completed:
						g_lbl.text = "ALTAR DE INVOCACIÓN: GORGON (ANTENA SR-04)\n[Mantén la zona 5s para emitir baliza orbital]"


func _unlock_forward_bridge() -> void:
	_is_forward_bridge_unlocked = true
	if _forward_bridge_pad and is_instance_valid(_forward_bridge_pad):
		var mesh: MeshInstance3D = _forward_bridge_pad.get_node_or_null("Mesh") as MeshInstance3D
		if mesh:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.9, 1.0) * 0.8
			mesh.material_override = mat
		var lbl: Label3D = _forward_bridge_pad.get_node_or_null("Label3D") as Label3D
		if lbl:
			lbl.text = "🌀 PORTAL DE AVANZADA [ACTIVO]\n[Destino: Base Terran]"
			lbl.modulate = Color(0.3, 0.95, 1.0)
		_play_sfx_3d(&"upgrade_complete", _forward_bridge_pad.global_position)
		FloatingTextManager.spawn_text(self, _forward_bridge_pad.global_position + Vector3(0.0, 2.5, 0.0), "¡PUENTE EINSTEIN-ROSEN ACTIVADO!", Color(0.3, 0.95, 1.0))


func _spawn_teleport_network() -> void:
	# 1. Base Recall Pad (-18, 0, 22) near Armory
	_base_recall_pad = Area3D.new()
	_base_recall_pad.name = "BaseRecallPad"
	_base_recall_pad.position = Vector3(-18.0, 0.0, 22.0)
	_base_recall_pad.collision_layer = 0
	_base_recall_pad.collision_mask = 2

	var b_col := CollisionShape3D.new()
	var b_cyl_col := CylinderShape3D.new()
	b_cyl_col.radius = 2.0
	b_cyl_col.height = 0.5
	b_col.shape = b_cyl_col
	b_col.position = Vector3(0.0, 0.25, 0.0)
	_base_recall_pad.add_child(b_col)

	var b_mesh := MeshInstance3D.new()
	b_mesh.name = "Mesh"
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 1.8
	b_cyl.bottom_radius = 2.0
	b_cyl.height = 0.15
	b_mesh.mesh = b_cyl
	b_mesh.position = Vector3(0.0, 0.08, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.15, 0.7, 0.95)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.2, 0.8, 1.0) * 0.8
	b_mesh.material_override = b_mat
	_base_recall_pad.add_child(b_mesh)

	var b_lbl := Label3D.new()
	b_lbl.name = "Label3D"
	b_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b_lbl.position = Vector3(0.0, 1.8, 0.0)
	b_lbl.font_size = 20
	b_lbl.modulate = Color(0.3, 0.85, 1.0)
	b_lbl.text = "🌀 PORTAL BASE (PUENTE EINSTEIN-ROSEN)\n[Destino: Centro del Mapa]"
	_base_recall_pad.add_child(b_lbl)

	_base_recall_pad.body_entered.connect(func(body: Node3D):
		if _is_forward_bridge_unlocked and _teleport_cooldown <= 0.0:
			if body.is_in_group("allies") or body.is_in_group("heroes"):
				_teleport_cooldown = 2.0
				body.global_position = Vector3(0.0, 0.5, 0.0)
				_play_sfx_3d(&"upgrade_complete", Vector3(0.0, 0.5, 0.0))
				FloatingTextManager.spawn_text(self, Vector3(0.0, 2.5, 0.0), "TELETRANSPORTE A AVANZADA", Color(0.2, 0.9, 1.0))
	)
	add_child(_base_recall_pad)

	# 2. Forward Bridge Pad (0, 0, 0) Center of Map
	_forward_bridge_pad = Area3D.new()
	_forward_bridge_pad.name = "ForwardBridgePad"
	_forward_bridge_pad.position = Vector3(0.0, 0.0, 0.0)
	_forward_bridge_pad.collision_layer = 0
	_forward_bridge_pad.collision_mask = 2

	var f_col := CollisionShape3D.new()
	var f_cyl_col := CylinderShape3D.new()
	f_cyl_col.radius = 2.2
	f_cyl_col.height = 0.5
	f_col.shape = f_cyl_col
	f_col.position = Vector3(0.0, 0.25, 0.0)
	_forward_bridge_pad.add_child(f_col)

	var f_mesh := MeshInstance3D.new()
	f_mesh.name = "Mesh"
	var f_cyl := CylinderMesh.new()
	f_cyl.top_radius = 2.0
	f_cyl.bottom_radius = 2.2
	f_cyl.height = 0.15
	f_mesh.mesh = f_cyl
	f_mesh.position = Vector3(0.0, 0.08, 0.0)
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.8, 0.5, 0.1)
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.6, 0.1) * 0.5
	f_mesh.material_override = f_mat
	_forward_bridge_pad.add_child(f_mesh)

	var f_lbl := Label3D.new()
	f_lbl.name = "Label3D"
	f_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f_lbl.position = Vector3(0.0, 1.8, 0.0)
	f_lbl.font_size = 20
	f_lbl.modulate = Color(1.0, 0.75, 0.2)
	f_lbl.text = "🌀 PORTAL DE AVANZADA\n[500 💎 PARA ACTIVAR]"
	_forward_bridge_pad.add_child(f_lbl)

	_forward_bridge_pad.body_entered.connect(func(body: Node3D):
		if _is_forward_bridge_unlocked and _teleport_cooldown <= 0.0:
			if body.is_in_group("allies") or body.is_in_group("heroes"):
				_teleport_cooldown = 2.0
				body.global_position = Vector3(-18.0, 0.5, 22.0)
				_play_sfx_3d(&"upgrade_complete", Vector3(-18.0, 0.5, 22.0))
				FloatingTextManager.spawn_text(self, Vector3(-18.0, 2.5, 22.0), "TELETRANSPORTE A BASE", Color(0.2, 0.9, 1.0))
	)
	add_child(_forward_bridge_pad)


func _on_recall_base_requested() -> void:
	if active_hero and is_instance_valid(active_hero):
		var target_pos := Vector3(-20.0, 0.5, 20.0)
		active_hero.global_position = target_pos
		_play_sfx_3d(&"upgrade_complete", target_pos)
		FloatingTextManager.spawn_text(self, target_pos + Vector3(0.0, 2.5, 0.0), "¡RECALL TÁCTICO A BASE!", Color(0.2, 0.95, 1.0))
		if rts_controller:
			var units: Array = rts_controller.get_selected_units()
			for u in units:
				if is_instance_valid(u) and u != active_hero:
					u.global_position = target_pos + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))


func _spawn_oracle_orb() -> void:
	_oracle_orb_node = Area3D.new()
	_oracle_orb_node.name = "OracleOrbXelNaga"
	_oracle_orb_node.position = Vector3(24.0, 0.0, 24.0)
	_oracle_orb_node.collision_layer = 0
	_oracle_orb_node.collision_mask = 2

	var col := CollisionShape3D.new()
	var sphere_col := SphereShape3D.new()
	sphere_col.radius = 3.5
	col.shape = sphere_col
	_oracle_orb_node.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.65
	s_mesh.height = 1.3
	mesh_inst.mesh = s_mesh
	mesh_inst.position = Vector3(0.0, 1.2, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.84, 0.0)
	mat.emission_energy_multiplier = 3.5
	mesh_inst.material_override = mat
	_oracle_orb_node.add_child(mesh_inst)

	var lbl := Label3D.new()
	lbl.name = "Label3D"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 2.3, 0.0)
	lbl.font_size = 22
	lbl.modulate = Color(1.0, 0.9, 0.3)
	lbl.text = "🔮 ORBE ORÁCULO XEL'NAGA\n[Acércate para recibir pista]"
	_oracle_orb_node.add_child(lbl)

	_oracle_orb_node.body_entered.connect(func(body: Node3D):
		if body.is_in_group("allies") or body.is_in_group("heroes"):
			_trigger_oracle_hint(_oracle_orb_node)
	)

	add_child(_oracle_orb_node)


func _trigger_oracle_hint(orb: Node3D) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_oracle_hint_time < 3500:
		return
	_last_oracle_hint_time = now

	if not pedestal_puzzle:
		return
	var hints: Array[int] = pedestal_puzzle.get_solver_hints()
	if hints.is_empty():
		FloatingTextManager.spawn_text(self, orb.global_position + Vector3(0.0, 2.5, 0.0), "ORÁCULO: ¡EL PUZZLE YA ESTÁ RESUELTO!", Color(0.2, 1.0, 0.4))
		return

	var next_ped: int = hints[0]
	if next_ped >= 0 and next_ped < pedestal_puzzle.pedestals.size():
		var ped_node: Node3D = pedestal_puzzle.pedestals[next_ped]
		if is_instance_valid(ped_node) and ped_node.has_method("flash_hint"):
			ped_node.flash_hint(4.0)

	FloatingTextManager.spawn_text(self, orb.global_position + Vector3(0.0, 2.5, 0.0), "ORÁCULO XEL'NAGA: Pisa el Pedestal [%d]" % next_ped, Color(1.0, 0.84, 0.0))
	_play_sfx_3d(&"upgrade_complete", orb.global_position)


func _spawn_pinnacle_altars() -> void:
	# 1. Altar 1 — Odin, Titan of Armageddon (-20, 0, -20)
	_pinnacle_altar_odin = Area3D.new()
	_pinnacle_altar_odin.name = "AltarOdin"
	_pinnacle_altar_odin.position = Vector3(-20.0, 0.0, -20.0)
	_pinnacle_altar_odin.collision_layer = 0
	_pinnacle_altar_odin.collision_mask = 2

	var o_col := CollisionShape3D.new()
	var o_cyl_col := CylinderShape3D.new()
	o_cyl_col.radius = 3.5
	o_cyl_col.height = 0.5
	o_col.shape = o_cyl_col
	_pinnacle_altar_odin.add_child(o_col)

	var o_mesh := MeshInstance3D.new()
	var o_cyl := CylinderMesh.new()
	o_cyl.top_radius = 3.2
	o_cyl.bottom_radius = 3.5
	o_cyl.height = 0.2
	o_mesh.mesh = o_cyl
	var o_mat := StandardMaterial3D.new()
	o_mat.albedo_color = Color(0.85, 0.3, 0.1)
	o_mat.emission_enabled = true
	o_mat.emission = Color(1.0, 0.35, 0.1) * 0.7
	o_mesh.material_override = o_mat
	_pinnacle_altar_odin.add_child(o_mesh)

	var o_lbl := Label3D.new()
	o_lbl.name = "Label3D"
	o_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	o_lbl.position = Vector3(0.0, 2.5, 0.0)
	o_lbl.font_size = 22
	o_lbl.modulate = Color(1.0, 0.45, 0.15)
	o_lbl.text = "ALTAR DE INVOCACIÓN: ODIN, TITAN OF ARMAGEDDON\n[3 Balizas Tácticas: 0/3]"
	_pinnacle_altar_odin.add_child(o_lbl)
	add_child(_pinnacle_altar_odin)

	# 3 Odin Beacons along NW-SE diagonal
	_odin_beacons.clear()
	_odin_beacons_active = 0
	var beacon_coords := [Vector3(-24.0, 0.0, -24.0), Vector3(-20.0, 0.0, -20.0), Vector3(-16.0, 0.0, -16.0)]
	for bi in range(beacon_coords.size()):
		var b_pos: Vector3 = beacon_coords[bi]
		var b_area := Area3D.new()
		b_area.name = "OdinBeacon_%d" % (bi + 1)
		b_area.position = b_pos
		b_area.collision_layer = 0
		b_area.collision_mask = 2

		var b_c := CollisionShape3D.new()
		var b_cy := CylinderShape3D.new()
		b_cy.radius = 1.8
		b_cy.height = 0.4
		b_c.shape = b_cy
		b_area.add_child(b_c)

		var b_m := MeshInstance3D.new()
		b_m.name = "Mesh"
		var b_cm := CylinderMesh.new()
		b_cm.top_radius = 1.4
		b_cm.bottom_radius = 1.6
		b_cm.height = 0.1
		b_m.mesh = b_cm
		var b_mt := StandardMaterial3D.new()
		b_mt.albedo_color = Color(0.5, 0.2, 0.1)
		b_mt.emission_enabled = true
		b_mt.emission = Color(0.8, 0.3, 0.1) * 0.4
		b_m.material_override = b_mt
		b_area.add_child(b_m)

		b_area.body_entered.connect(func(body: Node3D):
			if not b_area.get_meta("is_active", false) and (body.is_in_group("allies") or body.is_in_group("heroes")):
				b_area.set_meta("is_active", true)
				_odin_beacons_active += 1
				var mesh_inst: MeshInstance3D = b_area.get_node_or_null("Mesh") as MeshInstance3D
				if mesh_inst and mesh_inst.material_override is StandardMaterial3D:
					var m: StandardMaterial3D = mesh_inst.material_override as StandardMaterial3D
					m.albedo_color = Color(1.0, 0.84, 0.0)
					m.emission = Color(1.0, 0.84, 0.0) * 0.9
				_play_sfx_3d(&"upgrade_complete", b_area.global_position)
				FloatingTextManager.spawn_text(self, b_area.global_position + Vector3(0.0, 2.0, 0.0), "Baliza Táctica Activa (%d/3)" % _odin_beacons_active, Color(1.0, 0.85, 0.2))
				if o_lbl:
					o_lbl.text = "ALTAR DE INVOCACIÓN: ODIN, TITAN OF ARMAGEDDON\n[3 Balizas Tácticas: %d/3]" % _odin_beacons_active
				if _odin_beacons_active >= 3 and not _pinnacle_altar_odin.get_meta("is_summoned", false):
					_pinnacle_altar_odin.set_meta("is_summoned", true)
					if o_lbl:
						o_lbl.text = "ALTAR DE ODIN\n[¡TITÁN DESPERTADO!]"
					_spawn_pinnacle_boss(&"odin", Vector3(-20.0, 0.0, -20.0))
		)
		add_child(b_area)
		_odin_beacons.append(b_area)

	# 2. Altar 2 — Gorgon, the Skycleaver (30, 0, 30) Antena SR-04
	_pinnacle_altar_gorgon = Area3D.new()
	_pinnacle_altar_gorgon.name = "AltarGorgon"
	_pinnacle_altar_gorgon.position = Vector3(30.0, 0.0, 30.0)
	_pinnacle_altar_gorgon.collision_layer = 0
	_pinnacle_altar_gorgon.collision_mask = 2

	var g_col := CollisionShape3D.new()
	var g_cyl_col := CylinderShape3D.new()
	g_cyl_col.radius = 4.0
	g_cyl_col.height = 0.5
	g_col.shape = g_cyl_col
	_pinnacle_altar_gorgon.add_child(g_col)

	var g_mesh := MeshInstance3D.new()
	var g_cyl := CylinderMesh.new()
	g_cyl.top_radius = 3.6
	g_cyl.bottom_radius = 4.0
	g_cyl.height = 0.2
	g_mesh.mesh = g_cyl
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.2, 0.65, 0.95)
	g_mat.emission_enabled = true
	g_mat.emission = Color(0.25, 0.75, 1.0) * 0.7
	g_mesh.material_override = g_mat
	_pinnacle_altar_gorgon.add_child(g_mesh)

	var g_lbl := Label3D.new()
	g_lbl.name = "Label3D"
	g_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g_lbl.position = Vector3(0.0, 2.5, 0.0)
	g_lbl.font_size = 22
	g_lbl.modulate = Color(0.3, 0.85, 1.0)
	g_lbl.text = "ALTAR DE INVOCACIÓN: GORGON (ANTENA SR-04)\n[Mantén la zona 5s para emitir baliza orbital]"
	_pinnacle_altar_gorgon.add_child(g_lbl)
	add_child(_pinnacle_altar_gorgon)

	# 3. Altar 3 — Celestial Kerrigan (12, 0, -25) Altar Slayn
	_pinnacle_altar_kerrigan = Area3D.new()
	_pinnacle_altar_kerrigan.name = "AltarKerrigan"
	_pinnacle_altar_kerrigan.position = Vector3(12.0, 0.0, -25.0)
	_pinnacle_altar_kerrigan.collision_layer = 0
	_pinnacle_altar_kerrigan.collision_mask = 2

	var k_col := CollisionShape3D.new()
	var k_cyl_col := CylinderShape3D.new()
	k_cyl_col.radius = 3.5
	k_cyl_col.height = 0.5
	k_col.shape = k_cyl_col
	_pinnacle_altar_kerrigan.add_child(k_col)

	var k_mesh := MeshInstance3D.new()
	var k_cyl := CylinderMesh.new()
	k_cyl.top_radius = 3.2
	k_cyl.bottom_radius = 3.5
	k_cyl.height = 0.2
	k_mesh.mesh = k_cyl
	var k_mat := StandardMaterial3D.new()
	k_mat.albedo_color = Color(0.75, 0.15, 0.9)
	k_mat.emission_enabled = true
	k_mat.emission = Color(0.85, 0.2, 1.0) * 0.8
	k_mesh.material_override = k_mat
	_pinnacle_altar_kerrigan.add_child(k_mesh)

	var k_lbl := Label3D.new()
	k_lbl.name = "Label3D"
	k_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	k_lbl.position = Vector3(0.0, 2.5, 0.0)
	k_lbl.font_size = 22
	k_lbl.modulate = Color(0.9, 0.35, 1.0)
	k_lbl.text = "ALTAR SLAYN: CELESTIAL KERRIGAN\n[Acércate para despertar el Renacer Celestial]"
	_pinnacle_altar_kerrigan.add_child(k_lbl)

	_pinnacle_altar_kerrigan.body_entered.connect(func(body: Node3D):
		if not _pinnacle_altar_kerrigan.get_meta("is_summoned", false) and (body.is_in_group("allies") or body.is_in_group("heroes")):
			_pinnacle_altar_kerrigan.set_meta("is_summoned", true)
			if k_lbl:
				k_lbl.text = "ALTAR SLAYN\n[¡CELESTIAL KERRIGAN DESPERTADA!]"
			_spawn_pinnacle_boss(&"celestial_kerrigan", Vector3(12.0, 0.0, -25.0))
	)
	add_child(_pinnacle_altar_kerrigan)


func _spawn_pinnacle_boss(boss_id: StringName, spawn_pos: Vector3) -> PinnacleBossBase:
	var info: Dictionary = PinnacleBossCatalog.get_boss_info(boss_id)
	if info.is_empty():
		return null

	var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
	if SFXM and SFXM.instance != null:
		SFXM.instance.play_voice_alert(&"wave_incoming")

	var boss := PinnacleBossBase.new()
	boss.name = "PinnacleBoss_" + str(boss_id).capitalize()
	boss.boss_id = boss_id
	boss.boss_name = str(info.get("name", "Pinnacle Boss"))
	boss.max_health = float(info.get("hp", 16000.0))
	boss.current_health = boss.max_health
	boss.flat_armor = float(info.get("armor", 18.0))
	boss.attack_damage = float(info.get("damage", 120.0))
	boss.reward_minerals = 100000
	boss.reward_rank_points = 300
	boss.secret_unit_unlocked = info.get("secret_unit", &"")
	boss.position = spawn_pos

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.0
	cyl.height = 4.0
	col.shape = cyl
	col.position = Vector3(0.0, 2.0, 0.0)
	boss.add_child(col)
	boss.collision_layer = 4
	boss.collision_mask = 1 | 2

	var mesh_inst := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 1.6
	b_mesh.bottom_radius = 2.0
	b_mesh.height = 3.6
	mesh_inst.mesh = b_mesh
	mesh_inst.position = Vector3(0.0, 1.8, 0.0)

	var b_mat := StandardMaterial3D.new()
	match boss_id:
		&"odin":
			b_mat.albedo_color = Color(0.9, 0.25, 0.1)
			b_mat.emission_enabled = true
			b_mat.emission = Color(1.0, 0.3, 0.1) * 0.8
		&"gorgon":
			b_mat.albedo_color = Color(0.2, 0.7, 1.0)
			b_mat.emission_enabled = true
			b_mat.emission = Color(0.2, 0.8, 1.0) * 0.8
		&"celestial_kerrigan":
			b_mat.albedo_color = Color(0.85, 0.15, 0.95)
			b_mat.emission_enabled = true
			b_mat.emission = Color(0.9, 0.2, 1.0) * 0.9
	mesh_inst.material_override = b_mat
	boss.add_child(mesh_inst)

	boss.boss_defeated_rewards.connect(func(mins: int, r_pts: int, sec_unit: StringName):
		_on_pinnacle_boss_defeated(boss_id, mins, r_pts, sec_unit, boss.global_position)
	)

	add_child(boss)

	if boss_health_bar_ui:
		boss_health_bar_ui.bind_boss(boss)

	if sc2_hud_root and sc2_hud_root.alert_label:
		sc2_hud_root.trigger_alert("¡ALERTA CÚSPIDE! %s HA ENTRADO EN COMBATE" % boss.boss_name.to_upper(), 7.0)

	return boss


func _on_pinnacle_boss_defeated(boss_id: StringName, _minerals: int, _rank_pts: int, secret_unit: StringName, pos: Vector3) -> void:
	var sess := _get_game_session()
	var diff_tier: int = sess.difficulty_tier if sess and "difficulty_tier" in sess else 1
	var _summary := BossRewardManager.process_pinnacle_victory(boss_id, economy_manager, diff_tier, secret_unit)

	match boss_id:
		&"odin":
			AchievementSystem.unlock_achievement(&"ach_odin_slayer")
		&"gorgon":
			AchievementSystem.unlock_achievement(&"ach_gorgon_slayer")
		&"celestial_kerrigan":
			AchievementSystem.unlock_achievement(&"ach_kerrigan_slayer")

	session_kills += 1
	if active_hero:
		active_hero.gain_experience(15000)

	FloatingTextManager.spawn_text(self, pos + Vector3(0.0, 3.0, 0.0), "+100.000 💎 | +300 RANGO (%s DERROTADO)" % str(boss_id).to_upper(), Color(1.0, 0.85, 0.2))
	_play_sfx_3d(&"zerg_death", pos)


func _end_game(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	var final_kills: int = session_kills
	_save_bank_progress(!victory)
	session_kills = final_kills
	
	if is_waves_mode and not victory and game_over_panel:
		game_over_panel.visible = true
	
	var total_min: int = economy_manager.total_minerals_earned if economy_manager else 0
	var total_sp: int = 10
	var cleared: int = spawners_destroyed_count if not victory else total_sp
	var sess := _get_game_session()
	var current_seed: int = sess.map_seed if sess and "map_seed" in sess else 0
	var diff_tier: int = sess.difficulty_tier if sess and "difficulty_tier" in sess else SFEDifficultyManager.current_difficulty

	# 1. Rank delta calculation & Bank persistence (Tasks 12.1, 12.2)
	var bosses_slain: int = 0
	if story_phase_manager:
		bosses_slain = story_phase_manager.pinnacle_bosses_defeated_count
	var match_outcome: Dictionary = RankSystem.calculate_match_outcome(
		"victory" if victory else "defeat",
		diff_tier,
		1,
		bosses_slain
	)
	var rank_delta: int = match_outcome.get("delta", 0)
	var bank: Dictionary = BankManager.load_bank()
	var cur_rank_pts: int = bank.get("rank_points", 0)
	var new_rank_pts: int = cur_rank_pts + rank_delta
	bank["rank_points"] = new_rank_pts
	BankManager.save_bank(bank)

	# 2. Lifetime stats in PlayerProfileStats (Task 12.10)
	var profile_stats := PlayerProfileStats.new()
	var ped_solved: int = 1 if (sess and "pedestal_bonus_active" in sess and sess.pedestal_bonus_active) else 0
	profile_stats.record_game_finished(
		victory,
		diff_tier,
		total_min,
		final_kills,
		bosses_slain,
		ped_solved
	)

	# 3. Evaluate and unlock achievements (Tasks 12.3, 12.4, 16.1)
	var session_unlocked_achievements: Array[String] = []
	var achievements_enabled: bool = true
	if sess and sess.has_meta("achievements_enabled"):
		achievements_enabled = bool(sess.get_meta("achievements_enabled"))
	elif active_hero and active_hero.hero_data and active_hero.hero_data.is_secret:
		achievements_enabled = false

	if achievements_enabled:
		if victory:
			if AchievementSystem.unlock_achievement(&"ach_first_blood"):
				session_unlocked_achievements.append("Primera Sangre")
			if diff_tier >= 3:
				if AchievementSystem.unlock_achievement(&"ach_brutal_conqueror"):
					session_unlocked_achievements.append("Conquistador Brutal")
			if diff_tier >= 4:
				if AchievementSystem.unlock_achievement(&"ach_torment_conqueror"):
					session_unlocked_achievements.append("Señor del Tormento")
			if sess and sess.has_meta("is_random_selected") and bool(sess.get_meta("is_random_selected")):
				if AchievementSystem.unlock_achievement(&"ach_random_faith"):
					session_unlocked_achievements.append("Fe en el Destino")
			if game_mode_manager and game_mode_manager.current_mode_id == &"hardcore":
				if AchievementSystem.unlock_achievement(&"ach_hardcore_hero"):
					session_unlocked_achievements.append("Sin Atajos (Hardcore)")
			if command_center and command_center.current_health >= command_center.max_health:
				if AchievementSystem.unlock_achievement(&"ach_iron_defense"):
					session_unlocked_achievements.append("Muralla Inexpugnable")
		if total_min >= 500000:
			if AchievementSystem.unlock_achievement(&"ach_mineral_tycoon"):
				session_unlocked_achievements.append("Magnate del Mineral")

	var modal := SFEGameOverModal.new()
	modal.setup(
		victory,
		match_timer,
		final_kills,
		total_min,
		cleared,
		total_sp,
		SFEDifficultyManager.get_difficulty_name(),
		current_seed,
		RankSystem.get_rank_string(new_rank_pts),
		rank_delta,
		session_unlocked_achievements
	)
	add_child(modal)


func _on_all_spawners_cleared() -> void:
	if story_phase_manager:
		match story_phase_manager.current_phase:
			StoryPhaseManager.StoryPhase.ZERG:
				if story_phase_manager.allow_protoss_phases:
					story_phase_manager.advance_to_phase(StoryPhaseManager.StoryPhase.PROTOSS_1)
					_setup_protoss_spawner_network()
					_refresh_phase_hud()
					return
				else:
					story_phase_manager.advance_to_phase(StoryPhaseManager.StoryPhase.PINNACLE_BOSSES)
					_refresh_phase_hud()
					return
			StoryPhaseManager.StoryPhase.PROTOSS_1:
				story_phase_manager.advance_to_phase(StoryPhaseManager.StoryPhase.PROTOSS_2)
				_spawn_xelnaga_crystals()
				_refresh_phase_hud()
				return
			StoryPhaseManager.StoryPhase.PROTOSS_2, StoryPhaseManager.StoryPhase.PINNACLE_BOSSES:
				return
	_end_game(true)


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
		var sess := _get_game_session()
		var seed_val: int = sess.map_seed if sess and "map_seed" in sess and sess.map_seed != 0 else 12345
		pedestal_puzzle.setup_deterministic_initial_state(seed_val)
		if not pedestal_puzzle.puzzle_solved.is_connected(_on_pedestal_puzzle_solved):
			pedestal_puzzle.puzzle_solved.connect(_on_pedestal_puzzle_solved)

	_spawn_oracle_orb()
	_spawn_pinnacle_altars()
	_spawn_teleport_network()

	if sc2_hud_root and not sc2_hud_root.recall_base_requested.is_connected(_on_recall_base_requested):
		sc2_hud_root.recall_base_requested.connect(_on_recall_base_requested)


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
		var hit_target: bool = false
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
				hit_target = true

		# If no swarm unit was attacked within range, check for enemy nodes (SpawnerNode or Bosses)
		if not hit_target and get_tree():
			var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
			var closest_enemy: Node3D = null
			var closest_dist: float = ally_range
			for e in enemies:
				if not is_instance_valid(e) or not (e is Node3D) or e == ally:
					continue
				var dist: float = ally.global_position.distance_to((e as Node3D).global_position)
				if dist <= closest_dist:
					closest_dist = dist
					closest_enemy = e as Node3D
			if closest_enemy:
				if combat_vfx_pool:
					combat_vfx_pool.spawn_tracer(ally.global_position + Vector3(0.0, 1.1, 0.0), closest_enemy.global_position + Vector3(0.0, 1.0, 0.0))
				if closest_enemy.has_method("take_damage_context"):
					closest_enemy.take_damage_context(ally_dmg, CombatTypes.DamageType.PHYSICAL, false, 0)
				elif closest_enemy.has_method("take_damage"):
					closest_enemy.take_damage(ally_dmg)

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
	if structure is CommandCenter or (structure is Node and structure.is_in_group("structures")):
		var now_sec: float = Time.get_ticks_msec() / 1000.0
		if (now_sec - _last_base_attack_sfx_time) >= 12.0:
			_last_base_attack_sfx_time = now_sec
			var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
			if SFXM and SFXM.instance != null:
				SFXM.instance.play_voice_alert(&"base_under_attack")

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
	if not is_waves_mode:
		return
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
	if not is_waves_mode:
		return
	if state_label and wave_manager and wave_manager.is_wave_in_progress:
		state_label.text = "¡OLEADA EN CURSO! (Hostiles: %d)" % alive_count
	if sc2_hud_root:
		var cur_w: int = wave_manager.current_wave if wave_manager else 1
		sc2_hud_root.update_wave_status(cur_w, alive_count, true)


func _on_wave_completed(wave_number: int) -> void:
	if not is_waves_mode:
		return
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
	if not is_waves_mode:
		return
	if wave_manager:
		wave_manager.start_next_wave()


func _on_base_destroyed() -> void:
	_end_game(false)


func _save_bank_progress(is_loss: bool) -> void:
	var bank: Dictionary = BankManager.load_bank()
	var prev_kills: int = bank.get("total_kills", 0)
	var new_total_kills: int = prev_kills + session_kills
	bank["total_kills"] = new_total_kills
	var new_vet: int = maxi(1, 1 + int(new_total_kills / 100))
	bank["veterancy_level"] = new_vet

	if is_loss:
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


# ==============================================================================
# SFE5 Inner Classes: Xel'Naga Crystals, Outhouse, Mystery Boxes, Lucky Lizard
# ==============================================================================

class XelNagaCrystal3D extends StaticBody3D:
	var max_health: float = 5000.0
	var current_health: float = 5000.0
	var flat_armor: float = 8.0
	var crystal_index: int = 0
	var main_level_ref: Node = null

	func take_damage_context(amount: float, _dt: int = 0, _aoe: bool = false, _al: int = 0) -> void:
		take_damage(amount)

	func take_damage(amount: float) -> void:
		if current_health <= 0.0:
			return
		var dmg: float = maxf(1.0, amount - flat_armor)
		current_health = maxf(0.0, current_health - dmg)
		FloatingTextManager.spawn_text(self, global_position + Vector3(0.0, 3.5, 0.0), "-%d" % int(dmg), Color(0.3, 1.0, 0.5))
		if current_health <= 0.0:
			if main_level_ref and main_level_ref.has_method("_on_xelnaga_crystal_harmonized"):
				main_level_ref._on_xelnaga_crystal_harmonized(crystal_index)
			queue_free()


class MysteryBox3D extends StaticBody3D:
	var box_index: int = 0
	var main_level_ref: Node = null

	func take_damage_context(amount: float, _dt: int = 0, _aoe: bool = false, _al: int = 0) -> void:
		take_damage(amount)

	func take_damage(_amount: float) -> void:
		if main_level_ref and main_level_ref.has_method("_trigger_mystery_box_interaction"):
			main_level_ref._trigger_mystery_box_interaction(self, box_index)


class Outhouse3D extends StaticBody3D:
	var main_level_ref: Node = null

	func take_damage_context(amount: float, _dt: int = 0, _aoe: bool = false, _al: int = 0) -> void:
		take_damage(amount)

	func take_damage(_amount: float) -> void:
		if main_level_ref and main_level_ref.has_method("_trigger_outhouse_interaction"):
			main_level_ref._trigger_outhouse_interaction(self)


class LuckyLizard3D extends CharacterBody3D:
	var max_health: float = 100.0
	var current_health: float = 100.0
	var flat_armor: float = 2.0
	var main_level_ref: Node = null

	func take_damage_context(amount: float, _dt: int = 0, _aoe: bool = false, _al: int = 0) -> void:
		take_damage(amount)

	func take_damage(amount: float) -> void:
		if current_health <= 0.0:
			return
		current_health = maxf(0.0, current_health - amount)
		if current_health <= 0.0:
			if main_level_ref and main_level_ref.has_method("_trigger_lucky_lizard_death"):
				main_level_ref._trigger_lucky_lizard_death(self)


class FuelingStation3D extends StaticBody3D:
	var main_level_ref: Node = null

	func take_damage_context(amount: float, _dt: int = 0, _aoe: bool = false, _al: int = 0) -> void:
		take_damage(amount)

	func take_damage(_amount: float) -> void:
		if main_level_ref and main_level_ref.has_method("_trigger_fueling_station_complete"):
			main_level_ref._trigger_fueling_station_complete(self)
