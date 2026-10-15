class_name MainLevel
extends Node3D

## MainLevel - Primary battleground for Sprint 1 & 2.
## Manages navigation mesh dynamic rebaking on breach, wave HUD updates, and base integrity.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var rts_controller: RTSController = $RTSController
@onready var camera_rig: RTSCamera3D = $RTSCamera3D
@onready var wave_manager: WaveManager = $WaveManager

# UI Elements
@onready var round_label: Label = $UI/WavePanel/MarginContainer/VBoxContainer/RoundLabel
@onready var state_label: Label = $UI/WavePanel/MarginContainer/VBoxContainer/StateLabel
@onready var cc_health_label: Label = $UI/WavePanel/MarginContainer/VBoxContainer/CCHealthLabel
@onready var start_wave_btn: Button = $UI/WavePanel/MarginContainer/VBoxContainer/StartWaveBtn
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var restart_btn: Button = $UI/GameOverPanel/MarginContainer/VBoxContainer/RestartBtn


func _ready() -> void:
	# Temporarily disable gate door collisions during bake so the navigation mesh
	# creates walkable corridors through the blast door openings.
	var gates: Array[Node] = get_tree().get_nodes_in_group("gates")
	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.door_collision:
				gate.door_collision.disabled = true

	# Ensure Jolt physics has updated the collision shape state before baking
	await get_tree().physics_frame

	# Ensure navigation mesh is baked with Static Colliders
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

	# Ensure navigation mesh is fully registered before restoring gate physical collision
	await get_tree().physics_frame

	# Restore gate states and collisions according to their configured initial_state
	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.initial_state == GateStructure.GateState.CLOSED:
				gate.close_gate(false)
			else:
				gate.open_gate(false)

	_setup_event_listeners()
	if game_over_panel:
		game_over_panel.visible = false


func _setup_event_listeners() -> void:
	SignalBus.structure_destroyed.connect(_on_structure_destroyed)
	SignalBus.structure_damaged.connect(_on_structure_damaged)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_completed.connect(_on_wave_completed)
	SignalBus.wave_enemy_count_changed.connect(_on_wave_enemy_count_changed)
	SignalBus.base_destroyed.connect(_on_base_destroyed)

	if start_wave_btn:
		start_wave_btn.pressed.connect(_on_start_wave_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)


func _on_structure_destroyed(structure: Node) -> void:
	if structure is CommandCenter:
		SignalBus.base_destroyed.emit()
		return

	# If a wall segment or gate is destroyed, re-bake navmesh so enemies path through the breach
	if (structure is WallSegment or structure is GateStructure) and nav_region:
		await get_tree().physics_frame
		nav_region.bake_navigation_mesh(true)


func _on_structure_damaged(structure: Node, current_hp: float, max_hp: float) -> void:
	if structure is CommandCenter and cc_health_label:
		cc_health_label.text = "Integridad Command Center: %d / %d" % [int(current_hp), int(max_hp)]
		if current_hp <= max_hp * 0.3:
			cc_health_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		elif current_hp <= max_hp * 0.6:
			cc_health_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))


func _on_wave_started(wave_number: int, total_enemies: int) -> void:
	if round_label:
		round_label.text = "Ronda Actual: %d" % wave_number
	if state_label:
		state_label.text = "¡OLEADA EN CURSO! (Hostiles: %d)" % total_enemies
		state_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if start_wave_btn:
		start_wave_btn.visible = false


func _on_wave_enemy_count_changed(alive_count: int) -> void:
	if state_label and wave_manager and wave_manager.is_wave_in_progress:
		state_label.text = "¡OLEADA EN CURSO! (Hostiles: %d)" % alive_count


func _on_wave_completed(wave_number: int) -> void:
	if round_label:
		round_label.text = "Ronda %d Completada" % wave_number
	if state_label:
		state_label.text = "Estado: FASE TÁCTICA"
		state_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	if start_wave_btn:
		start_wave_btn.visible = true
		start_wave_btn.text = "▶ INICIAR RONDA %d" % (wave_number + 1)


func _on_start_wave_pressed() -> void:
	if wave_manager:
		wave_manager.start_next_wave()


func _on_base_destroyed() -> void:
	if game_over_panel:
		game_over_panel.visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
