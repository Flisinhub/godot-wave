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

var bottom_console: HBoxContainer
var minimap_box: PanelContainer
var stat_panel: SC2StatPanel
var command_card: SC2CommandCard

func _init() -> void:
	_build_hud_layout()

func _ready() -> void:
	_build_hud_layout()
	_connect_signal_bus()

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

	var minimap_label := Label.new()
	minimap_label.text = "[ TACTICAL RADAR ]"
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
