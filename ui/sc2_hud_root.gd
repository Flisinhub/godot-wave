class_name SC2HUDRoot
extends CanvasLayer

## SC2HUDRoot - Root Controller for StarCraft II Style In-Game HUD.
## Assembles the procedural bottom console:
## - Bottom-Left: Minimap box / tactical radar
## - Bottom-Center: SC2StatPanel (wireframe, triple resource bars, STR/DEX/INT [+] attributes)
## - Bottom-Right: SC2CommandCard (3x5 procedural grid for hero abilities and RTS orders)
## Features full headless DisplayServer safety guards for CI/CD test execution.

const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const ArmoryModal = preload("res://ui/armory_modal.gd")

var bottom_console: HBoxContainer
var minimap_box: PanelContainer
var stat_panel: SC2StatPanel
var command_card: SC2CommandCard
var armory_modal: ArmoryModal = null

signal console_open_requested(tab_index: int)

# Top Bar Elements
var top_bar: PanelContainer
var top_diff_badge: Label
var top_seed_label: Label
var top_hive_label: Label
var enemy_budget_label: Label
var top_wave_label: Label
var top_cc_hp_label: Label
var top_minerals_label: Label
var top_supply_label: Label
var top_vet_label: Label

# Tactical Alert Banner & Minimap Indicator (Fase 8)
var alert_banner: PanelContainer
var alert_label: Label
var minimap_arrow: Label
var minimap_overlay: Control
var spawner_markers: Array = []
var _alert_timer: float = 0.0

func _init() -> void:
	_build_hud_layout()

func _ready() -> void:
	_build_hud_layout()
	_connect_signal_bus()
	_connect_armory_terminals()

func _build_hud_layout() -> void:
	if bottom_console != null:
		return

	# Root full-width bottom anchor container
	var root_control := Control.new()
	root_control.name = "HUDControlRoot"
	root_control.anchor_top = 0.0
	root_control.anchor_bottom = 1.0
	root_control.anchor_left = 0.0
	root_control.anchor_right = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	bottom_console = HBoxContainer.new()
	bottom_console.name = "BottomConsole"
	bottom_console.anchor_top = 1.0
	bottom_console.anchor_bottom = 1.0
	bottom_console.anchor_left = 0.0
	bottom_console.anchor_right = 1.0
	bottom_console.offset_top = -180.0
	bottom_console.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_console.add_theme_constant_override("separation", 10)

	# Procedural StarCraft II Console Background Panel
	var console_bg := Panel.new()
	console_bg.name = "ConsoleBackground"
	console_bg.anchor_top = 1.0
	console_bg.anchor_bottom = 1.0
	console_bg.anchor_left = 0.0
	console_bg.anchor_right = 1.0
	console_bg.offset_top = -186.0
	console_bg.offset_bottom = 0.0
	console_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var console_style := StyleBoxFlat.new()
	console_style.bg_color = Color(0.04, 0.07, 0.10, 0.95)
	console_style.border_width_top = 2
	console_style.border_width_left = 1
	console_style.border_width_right = 1
	console_style.border_width_bottom = 2
	console_style.border_color = Color(0.25, 0.55, 0.85, 0.8)
	console_style.corner_radius_top_left = 6
	console_style.corner_radius_top_right = 6
	console_style.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	console_style.shadow_size = 8
	console_bg.add_theme_stylebox_override("panel", console_style)
	root_control.add_child(console_bg)
	root_control.add_child(bottom_console)

	# 1. Bottom-Left: Minimap box
	minimap_box = PanelContainer.new()
	minimap_box.name = "MinimapBox"
	minimap_box.custom_minimum_size = Vector2(240, 180)

	var minimap_style := StyleBoxFlat.new()
	minimap_style.bg_color = Color(0.03, 0.05, 0.08, 0.92)
	minimap_style.border_width_top = 2
	minimap_style.border_width_bottom = 2
	minimap_style.border_width_left = 2
	minimap_style.border_width_right = 2
	minimap_style.border_color = Color(0.22, 0.45, 0.7, 0.75)
	minimap_style.corner_radius_top_left = 4
	minimap_style.corner_radius_top_right = 4
	minimap_style.corner_radius_bottom_left = 4
	minimap_style.corner_radius_bottom_right = 4
	minimap_style.content_margin_left = 8.0
	minimap_style.content_margin_right = 8.0
	minimap_style.content_margin_top = 8.0
	minimap_style.content_margin_bottom = 8.0
	minimap_box.add_theme_stylebox_override("panel", minimap_style)
	minimap_box.gui_input.connect(_on_minimap_gui_input)

	var minimap_label := Label.new()
	minimap_label.text = "[ TACTICAL RADAR ]"
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minimap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.9))
	minimap_label.add_theme_font_size_override("font_size", 13)
	minimap_box.add_child(minimap_label)

	minimap_arrow = Label.new()
	minimap_arrow.name = "MinimapAlertArrow"
	minimap_arrow.text = "▲"
	minimap_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minimap_arrow.visible = false
	minimap_arrow.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.95))
	minimap_arrow.add_theme_font_size_override("font_size", 22)
	minimap_box.add_child(minimap_arrow)

	minimap_overlay = Control.new()
	minimap_overlay.name = "MinimapOverlay"
	minimap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_overlay.draw.connect(_on_minimap_draw)
	minimap_box.add_child(minimap_overlay)

	bottom_console.add_child(minimap_box)

	# 2. Bottom-Center: Unit Stat Console
	stat_panel = SC2StatPanel.new()
	stat_panel.name = "StatPanel"
	if not stat_panel.console_open_requested.is_connected(func(): console_open_requested.emit(0)):
		stat_panel.console_open_requested.connect(func(): console_open_requested.emit(0))
	bottom_console.add_child(stat_panel)

	# 3. Bottom-Right: 3x5 Command Card
	command_card = SC2CommandCard.new()
	command_card.name = "CommandCard"
	if not command_card.command_triggered.is_connected(_on_command_card_command_triggered):
		command_card.command_triggered.connect(_on_command_card_command_triggered)
	bottom_console.add_child(command_card)

	# 4. StarCraft II Procedural Top Command Bar
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = 40.0

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.065, 0.095, 0.94)
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.22, 0.52, 0.85, 0.85)
	top_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	top_style.shadow_size = 6
	top_style.content_margin_left = 16.0
	top_style.content_margin_right = 16.0
	top_style.content_margin_top = 6.0
	top_style.content_margin_bottom = 6.0
	top_bar.add_theme_stylebox_override("panel", top_style)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_hbox.add_theme_constant_override("separation", 18)
	top_bar.add_child(top_hbox)

	# Left: Difficulty Badge & Hive Evolution
	top_diff_badge = Label.new()
	top_diff_badge.text = "[ NORMAL ]"
	top_diff_badge.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	top_diff_badge.add_theme_font_size_override("font_size", 13)
	top_hbox.add_child(top_diff_badge)

	top_seed_label = Label.new()
	top_seed_label.text = "SEED: 12345"
	top_seed_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	top_seed_label.add_theme_font_size_override("font_size", 11)
	top_hbox.add_child(top_seed_label)

	top_hive_label = Label.new()
	top_hive_label.text = "HIVE LVL 0 (Next: 120s)"
	top_hive_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.95))
	top_hive_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(top_hive_label)

	# Spacer
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer1)

	# Center: Enemy Budget & Objective / Wave info
	enemy_budget_label = Label.new()
	enemy_budget_label.text = "ENEMIGOS: 0 / 300"
	enemy_budget_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	enemy_budget_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(enemy_budget_label)

	# Center: Wave info & Command Center Integrity
	top_wave_label = Label.new()
	top_wave_label.text = "RONDA 1  |  HOSTILES: 0"
	top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	top_wave_label.add_theme_font_size_override("font_size", 13)
	top_hbox.add_child(top_wave_label)

	top_cc_hp_label = Label.new()
	top_cc_hp_label.text = "COMMAND CENTER: 2000 / 2000 HP"
	top_cc_hp_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))
	top_cc_hp_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(top_cc_hp_label)

	# Spacer
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer2)

	# Right: Minerals Wallet, Supply & Operator Veterancy
	top_minerals_label = Label.new()
	top_minerals_label.text = "💎 50 MINERALS"
	top_minerals_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	top_minerals_label.add_theme_font_size_override("font_size", 13)
	top_hbox.add_child(top_minerals_label)

	top_supply_label = Label.new()
	top_supply_label.text = "⚡ 1 / 80"
	top_supply_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	top_supply_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(top_supply_label)

	top_vet_label = Label.new()
	top_vet_label.text = "⭐ VET LVL 1"
	top_vet_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	top_vet_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(top_vet_label)

	root_control.add_child(top_bar)

	# 5. Tactical Threat Alert Banner (Fase 8)
	alert_banner = PanelContainer.new()
	alert_banner.name = "AlertBanner"
	alert_banner.anchor_left = 0.5
	alert_banner.anchor_right = 0.5
	alert_banner.offset_left = -260.0
	alert_banner.offset_right = 260.0
	alert_banner.offset_top = 46.0
	alert_banner.offset_bottom = 86.0
	alert_banner.visible = false

	var alert_style := StyleBoxFlat.new()
	alert_style.bg_color = Color(0.12, 0.02, 0.03, 0.92)
	alert_style.border_width_bottom = 2
	alert_style.border_width_top = 2
	alert_style.border_color = Color(1.0, 0.25, 0.2, 0.9)
	alert_style.corner_radius_bottom_left = 6
	alert_style.corner_radius_bottom_right = 6
	alert_banner.add_theme_stylebox_override("panel", alert_style)

	alert_label = Label.new()
	alert_label.name = "AlertLabel"
	alert_label.text = "⚠ ALERTA DE AMENAZA"
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	alert_label.add_theme_font_size_override("font_size", 14)
	alert_banner.add_child(alert_label)
	root_control.add_child(alert_banner)

func _connect_signal_bus() -> void:
	# Check if running headless with dummy display server
	var is_headless: bool = DisplayServer.get_name() == "headless"
	
	if Engine.has_singleton("SignalBus"):
		var sb: Node = Engine.get_singleton("SignalBus")
		if sb:
			_attach_to_bus(sb)
	elif ResourceLoader.exists("res://core/signal_bus.gd"):
		var root = get_tree().root if get_tree() else null
		if root and root.has_node("SignalBus"):
			var sb: Node = root.get_node("SignalBus")
			_attach_to_bus(sb)

func _attach_to_bus(bus: Node) -> void:
	if bus.has_signal("units_selected"):
		bus.connect("units_selected", _on_units_selected)
	if bus.has_signal("units_deselected"):
		bus.connect("units_deselected", _on_units_deselected)
	if bus.has_signal("armory_terminal_opened"):
		bus.connect("armory_terminal_opened", func(t: Node = null) -> void:
			open_armory_modal(t)
		)
	if bus.has_signal("scheduled_attack_warned"):
		bus.connect("scheduled_attack_warned", func(w: int, l: String, s: float, d: Vector3) -> void:
			show_attack_countdown(w, l, s, d)
		)
	if bus.has_signal("drop_pod_incoming"):
		bus.connect("drop_pod_incoming", func(_pos: Vector3, delay: float) -> void:
			show_drop_pod_alert(delay)
		)
	if bus.has_signal("nydus_tremor_alert"):
		bus.connect("nydus_tremor_alert", func(c: int, _p: Vector3, t: String) -> void:
			show_threat_alert("⚠ [TEMBLOR SUBTERRÁNEO] ¡%s emergiendo en Cráter %d!" % [t, c + 1], 4.0, Color(0.9, 0.35, 1.0))
		)


func _ensure_armory_modal() -> void:
	if armory_modal != null and is_instance_valid(armory_modal):
		return
	var modal_scene: PackedScene = load("res://ui/armory_modal.tscn") as PackedScene
	if modal_scene != null:
		armory_modal = modal_scene.instantiate() as ArmoryModal
	if armory_modal == null:
		armory_modal = ArmoryModal.new()
	armory_modal.name = "ArmoryModal"
	armory_modal.visible = false
	add_child(armory_modal)
	if not armory_modal.modal_closed.is_connected(_on_armory_modal_closed):
		armory_modal.modal_closed.connect(_on_armory_modal_closed)


func open_armory_modal(terminal: Node = null) -> void:
	_ensure_armory_modal()
	if armory_modal != null:
		armory_modal.open_modal(terminal)


func close_armory_modal() -> void:
	if armory_modal != null and armory_modal.visible:
		armory_modal.close_modal()


func _on_armory_modal_closed() -> void:
	pass


func _connect_armory_terminals() -> void:
	var terminals: Array = []
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null:
			terminals = tree.get_nodes_in_group("armory")
			if not tree.node_added.is_connected(_on_tree_node_added):
				tree.node_added.connect(_on_tree_node_added)
	var p: Node = get_parent()
	while p != null:
		for ch in p.get_children():
			if ch.is_in_group("armory") and not terminals.has(ch):
				terminals.append(ch)
		p = p.get_parent()
	for term in terminals:
		_bind_armory_terminal(term)


func _on_tree_node_added(node: Node) -> void:
	if node != null and (node.is_in_group("armory") or node.has_signal("terminal_opened")):
		_bind_armory_terminal(node)


func _bind_armory_terminal(term: Node) -> void:
	if term == null or not is_instance_valid(term):
		return
	if term.has_signal("terminal_opened") and not term.terminal_opened.is_connected(_on_terminal_opened.bind(term)):
		term.terminal_opened.connect(_on_terminal_opened.bind(term))
	if term.has_signal("terminal_closed") and not term.terminal_closed.is_connected(_on_terminal_closed):
		term.terminal_closed.connect(_on_terminal_closed)


func _on_terminal_opened(terminal: Node = null) -> void:
	open_armory_modal(terminal)


func _on_terminal_closed() -> void:
	if armory_modal != null and armory_modal.visible:
		close_armory_modal()

func _on_units_selected(units: Array) -> void:
	if units.is_empty():
		_on_units_deselected()
		return

	var primary_unit: Node = units[0] as Node
	if stat_panel:
		stat_panel.bind_unit(primary_unit)
	if command_card:
		command_card.populate_for_unit(primary_unit)

func _on_units_deselected() -> void:
	if stat_panel:
		stat_panel.bind_unit(null)
	if command_card:
		command_card.populate_for_unit(null)


func update_minerals(amount: int) -> void:
	if top_minerals_label:
		top_minerals_label.text = "💎 %d MINERALS" % amount


func update_supply(current: int, max_sup: int) -> void:
	if top_supply_label:
		top_supply_label.text = "⚡ %d / %d" % [current, max_sup]


func update_difficulty(diff_name: String, diff_tier: int = 1) -> void:
	if top_diff_badge:
		top_diff_badge.text = "[ %s ]" % diff_name.to_upper()
		var color: Color = Color(0.35, 0.85, 1.0)
		match diff_tier:
			0: color = Color(0.25, 0.95, 0.45) # Casual green
			1: color = Color(0.35, 0.85, 1.0)  # Normal cyan
			2: color = Color(1.0, 0.85, 0.25)  # Hard amber
			3: color = Color(1.0, 0.45, 0.2)   # Brutal orange
			4: color = Color(1.0, 0.2, 0.25)   # Torment crimson
		top_diff_badge.add_theme_color_override("font_color", color)


func update_seed(seed_value: int) -> void:
	if top_seed_label:
		top_seed_label.text = "SEED: %d" % seed_value


func update_enemy_budget(living: int, max_budget: int = 300, saturated: bool = false) -> void:
	if enemy_budget_label:
		enemy_budget_label.text = "ENEMIGOS: %d / %d" % [living, max_budget]
		enemy_budget_label.add_theme_color_override(
			"font_color", Color(1.0, 0.25, 0.25) if saturated else Color(0.9, 0.9, 0.9)
		)



func update_hive_evolution(lvl: int, time_remaining: float) -> void:
	if top_hive_label:
		top_hive_label.text = "HIVE LVL %d (Next: %ds)" % [lvl, int(ceilf(time_remaining))]


func update_revive_countdown(remaining: float, total: float) -> void:
	if top_wave_label:
		if remaining > 0.0:
			top_wave_label.text = "¡HÉROE CAÍDO! REVIVIENDO EN: %d s" % int(ceilf(remaining))
			top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		else:
			top_wave_label.text = "¡HÉROE REVIVIDO!"
			top_wave_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))


func update_wave_status(wave_num: int, swarm_alive: int, is_in_progress: bool = false) -> void:
	if top_wave_label:
		if is_in_progress:
			top_wave_label.text = "RONDA %d  |  ¡HOSTILES ACTIVOS: %d!" % [wave_num, swarm_alive]
			top_wave_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			top_wave_label.text = "RONDA %d  |  FASE TÁCTICA" % wave_num
			top_wave_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))


func update_command_center_hp(curr_hp: float, max_hp: float) -> void:
	if top_cc_hp_label:
		top_cc_hp_label.text = "COMMAND CENTER: %d / %d HP" % [int(curr_hp), int(max_hp)]
		if curr_hp <= max_hp * 0.3:
			top_cc_hp_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		elif curr_hp <= max_hp * 0.6:
			top_cc_hp_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		else:
			top_cc_hp_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))


func _on_command_card_command_triggered(cmd_id: String, _payload: Variant) -> void:
	if cmd_id == "open_console":
		console_open_requested.emit(0)
	elif cmd_id == "open_recruitment":
		console_open_requested.emit(3)


func update_story_phase(phase_title: String, bounty_info: int) -> void:
	if top_wave_label:
		top_wave_label.text = "FASE: %s  |  BOTÍN BASE: +%d 💎" % [phase_title.to_upper(), bounty_info]
		top_wave_label.add_theme_color_override("font_color", Color(0.25, 0.88, 1.0))


func update_veterancy(vet_level: int) -> void:
	if top_vet_label:
		top_vet_label.text = "⭐ VET LVL %d" % vet_level


func _on_minimap_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.is_pressed():
			_pan_camera_to_minimap_pos(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pan_camera_to_minimap_pos(mm.position)


func _pan_camera_to_minimap_pos(local_pos: Vector2) -> void:
	if not minimap_box:
		return
	var size: Vector2 = minimap_box.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var nx: float = clampf(local_pos.x / size.x, 0.0, 1.0)
	var ny: float = clampf(local_pos.y / size.y, 0.0, 1.0)
	var cam_rig = get_tree().get_first_node_in_group("rts_camera") if get_tree() else null
	if not cam_rig and get_tree() and get_tree().current_scene:
		cam_rig = get_tree().current_scene.get_node_or_null("RTSCamera3D")

	var bounds: Rect2 = Rect2(-38.0, -38.0, 76.0, 76.0)
	if cam_rig and "map_bounds" in cam_rig:
		bounds = cam_rig.map_bounds
	var world_x: float = bounds.position.x + nx * bounds.size.x
	var world_z: float = bounds.position.y + ny * bounds.size.y

	if cam_rig:
		if cam_rig.has_method("pan_to_position"):
			cam_rig.pan_to_position(Vector3(world_x, 0.0, world_z))
		else:
			cam_rig.global_position.x = world_x
			cam_rig.global_position.z = world_z


func update_spawner_markers(markers: Array) -> void:
	spawner_markers = markers
	if minimap_overlay:
		minimap_overlay.queue_redraw()


func _on_minimap_draw() -> void:
	if not minimap_overlay:
		return
	var box_size: Vector2 = minimap_overlay.size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return

	var map_half_extent: float = 50.0
	for m in spawner_markers:
		var world_pos: Vector3 = m.get("position", Vector3.ZERO)
		var state: int = m.get("state", 0)
		var nx: float = clampf((world_pos.x + map_half_extent) / (map_half_extent * 2.0), 0.08, 0.92)
		var ny: float = clampf((world_pos.z + map_half_extent) / (map_half_extent * 2.0), 0.08, 0.92)
		var draw_pos := Vector2(nx * box_size.x, ny * box_size.y)

		var color := Color(0.6, 0.6, 0.6) # Gris = Bloqueado (LOCKED)
		if state == 1: # ACTIVE
			color = Color(1.0, 0.2, 0.2) # Rojo = Activo
		elif state == 2: # DESTROYED
			color = Color(0.2, 0.95, 0.3) # Verde = Destruido

		minimap_overlay.draw_circle(draw_pos, 5.0, color)
		minimap_overlay.draw_arc(draw_pos, 6.0, 0, TAU, 16, Color(0.05, 0.08, 0.12), 1.5)



func _process(delta: float) -> void:
	if _alert_timer > 0.0:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			if alert_banner:
				alert_banner.visible = false
			if minimap_arrow:
				minimap_arrow.visible = false


func show_threat_alert(text: String, duration: float = 4.0, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	if alert_banner and alert_label:
		alert_label.text = text
		alert_label.add_theme_color_override("font_color", color)
		alert_banner.visible = true
	_alert_timer = duration


func show_attack_countdown(wave_index: int, leader_name: String, seconds_left: float, direction: Vector3) -> void:
	var dir_str: String = "NORTE"
	if direction.x > 0.3 and direction.z < -0.3:
		dir_str = "NORESTE (Colmena)"
	elif direction.x > 0.3:
		dir_str = "ESTE"
	elif direction.z < -0.3:
		dir_str = "NORTE"
	elif direction.x < -0.3:
		dir_str = "OESTE"
	elif direction.z > 0.3:
		dir_str = "SUR"

	var msg: String = "⚠ [ALERTA DE ASALTO] ¡Oleada %d (%s) en %ds desde el %s!" % [wave_index, leader_name, int(seconds_left), dir_str]
	show_threat_alert(msg, minf(seconds_left, 5.0), Color(1.0, 0.25, 0.2))

	if minimap_arrow:
		minimap_arrow.visible = true
		if direction.x > 0.0:
			minimap_arrow.text = "↗"
		else:
			minimap_arrow.text = "↖"


func show_drop_pod_alert(time_left: float) -> void:
	var msg: String = "⚠ [DROP POD ORBITAL] ¡Impacto inminente en %0.1fs fuera de la base!" % time_left
	show_threat_alert(msg, time_left + 1.0, Color(1.0, 0.5, 0.1))

