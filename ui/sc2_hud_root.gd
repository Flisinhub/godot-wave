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
	root_control.add_child(bottom_console)

	# 1. Bottom-Left: Minimap box
	minimap_box = PanelContainer.new()
	minimap_box.name = "MinimapBox"
	minimap_box.custom_minimum_size = Vector2(240, 180)
	var minimap_label := Label.new()
	minimap_label.text = "[ Tactical Radar ]"
	minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
