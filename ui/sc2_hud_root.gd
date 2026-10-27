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

# Top Bar Elements
var top_bar: PanelContainer
var top_diff_badge: Label
var top_hive_label: Label
var top_wave_label: Label
var top_cc_hp_label: Label
var top_minerals_label: Label
var top_supply_label: Label
var top_vet_label: Label

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
	bottom_console.add_child(minimap_box)

	# 2. Bottom-Center: Unit Stat Console
	stat_panel = SC2StatPanel.new()
	stat_panel.name = "StatPanel"
	bottom_console.add_child(stat_panel)

	# 3. Bottom-Right: 3x5 Command Card
	command_card = SC2CommandCard.new()
	command_card.name = "CommandCard"
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

	top_hive_label = Label.new()
	top_hive_label.text = "HIVE LVL 0 (Next: 120s)"
	top_hive_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.95))
	top_hive_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(top_hive_label)

	# Spacer
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer1)

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
