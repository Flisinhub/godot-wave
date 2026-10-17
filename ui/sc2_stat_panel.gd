class_name SC2StatPanel
extends PanelContainer

## Procedural StarCraft II Console / Unit Stat Panel UI.
## Displays unit wireframe, Health / Shield / Energy resource bars, and
## RPG Attribute progression (STR / DEX / INT with [+] buttons and unspent points counter).
## Built with headless DisplayServer safety guards.

const HeroData = preload("res://core/heroes/hero_data.gd")

var bound_unit: Node = null

# UI Child Nodes
var name_label: Label
var wireframe_rect: ColorRect
var hp_bar: ProgressBar
var hp_label: Label
var shield_bar: ProgressBar
var shield_label: Label
var energy_bar: ProgressBar
var energy_label: Label

# Attribute UI Elements
var attribute_container: VBoxContainer
var points_label: Label
var str_label: Label
var str_plus_btn: Button
var dex_label: Label
var dex_plus_btn: Button
var int_label: Label
var int_plus_btn: Button

func _init() -> void:
	custom_minimum_size = Vector2(480, 180)
	_build_ui_layout()

func _ready() -> void:
	_build_ui_layout()

func _build_ui_layout() -> void:
	if name_label != null:
		return

	var h_split := HBoxContainer.new()
	h_split.custom_minimum_size = Vector2(460, 170)
	add_child(h_split)

	# Left: Wireframe / Portrait Box
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(100, 160)
	wireframe_rect = ColorRect.new()
	wireframe_rect.custom_minimum_size = Vector2(90, 110)
	wireframe_rect.color = Color(0.12, 0.22, 0.35, 0.8)
	left_box.add_child(wireframe_rect)

	name_label = Label.new()
	name_label.text = "No Unit Selected"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_box.add_child(name_label)
	h_split.add_child(left_box)

	# Center: Triple Resource Bars (Health, Shield, Energy)
	var center_box := VBoxContainer.new()
	center_box.custom_minimum_size = Vector2(200, 160)

	# Health Bar
	hp_label = Label.new()
	hp_label.text = "Health: 0 / 0"
	center_box.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(190, 18)
	hp_bar.show_percentage = false
	center_box.add_child(hp_bar)

	# Shield Bar
	shield_label = Label.new()
	shield_label.text = "Shields: 0 / 0"
	center_box.add_child(shield_label)
	shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(190, 16)
	shield_bar.show_percentage = false
	center_box.add_child(shield_bar)

	# Energy Bar
	energy_label = Label.new()
	energy_label.text = "Energy: 0 / 0"
	center_box.add_child(energy_label)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(190, 16)
	energy_bar.show_percentage = false
	center_box.add_child(energy_bar)

	h_split.add_child(center_box)

	# Right: RPG Attributes Panel (STR, DEX, INT with [+] spend buttons)
	attribute_container = VBoxContainer.new()
	attribute_container.custom_minimum_size = Vector2(150, 160)

	points_label = Label.new()
	points_label.text = "Points: 0"
	attribute_container.add_child(points_label)

	# STR row
	var str_row := HBoxContainer.new()
	str_label = Label.new()
	str_label.text = "STR: 10"
	str_label.custom_minimum_size = Vector2(80, 24)
	str_row.add_child(str_label)
	str_plus_btn = Button.new()
	str_plus_btn.text = "[+]"
	str_plus_btn.custom_minimum_size = Vector2(32, 24)
	str_plus_btn.pressed.connect(func(): _on_attribute_allocated("str"))
	str_row.add_child(str_plus_btn)
	attribute_container.add_child(str_row)

	# DEX row
	var dex_row := HBoxContainer.new()
	dex_label = Label.new()
	dex_label.text = "DEX: 10"
	dex_label.custom_minimum_size = Vector2(80, 24)
	dex_row.add_child(dex_label)
	dex_plus_btn = Button.new()
	dex_plus_btn.text = "[+]"
	dex_plus_btn.custom_minimum_size = Vector2(32, 24)
	dex_plus_btn.pressed.connect(func(): _on_attribute_allocated("dex"))
	dex_row.add_child(dex_plus_btn)
	attribute_container.add_child(dex_row)

	# INT row
	var int_row := HBoxContainer.new()
	int_label = Label.new()
	int_label.text = "INT: 10"
	int_label.custom_minimum_size = Vector2(80, 24)
	int_row.add_child(int_label)
	int_plus_btn = Button.new()
	int_plus_btn.text = "[+]"
	int_plus_btn.custom_minimum_size = Vector2(32, 24)
	int_plus_btn.pressed.connect(func(): _on_attribute_allocated("int"))
	int_row.add_child(int_plus_btn)
	attribute_container.add_child(int_row)

	h_split.add_child(attribute_container)

	_clear_display()

func _process(_delta: float) -> void:
	if bound_unit and is_instance_valid(bound_unit):
		refresh_display()

func _clear_display() -> void:
	if name_label:
		name_label.text = "No Selection"
	if hp_label:
		hp_label.text = "Health: -- / --"
		hp_bar.value = 0
	if shield_label:
		shield_label.visible = false
		shield_bar.visible = false
	if energy_label:
		energy_label.visible = false
		energy_bar.visible = false
	if attribute_container:
		attribute_container.visible = false

## Binds a selected unit to this stat console.
func bind_unit(unit: Node) -> void:
	bound_unit = unit
	if unit == null or not is_instance_valid(unit):
		_clear_display()
		return

	refresh_display()

## Refreshes real-time statistics, bars, and attribute allocation button states.
func refresh_display() -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		_clear_display()
		return

	var is_hero: bool = "hero_data" in bound_unit and bound_unit.hero_data != null

	if is_hero:
		var hd: HeroData = bound_unit.hero_data
		if name_label:
			name_label.text = "%s (Lvl %d)" % [hd.hero_name, hd.xp_level]

		# Health
		if hp_label and hp_bar:
			hp_label.text = "Health: %d / %d" % [int(hd.current_hp), int(hd.max_hp)]
			hp_bar.max_value = hd.max_hp
			hp_bar.value = hd.current_hp

		# Shield
		if shield_label and shield_bar:
			if hd.max_shield > 0.0:
				shield_label.visible = true
				shield_bar.visible = true
				shield_label.text = "Shields: %d / %d" % [int(hd.current_shield), int(hd.max_shield)]
				shield_bar.max_value = hd.max_shield
				shield_bar.value = hd.current_shield
			else:
				shield_label.visible = false
				shield_bar.visible = false

		# Energy
		if energy_label and energy_bar:
			if hd.max_energy > 0.0:
				energy_label.visible = true
				energy_bar.visible = true
				energy_label.text = "Energy: %d / %d" % [int(hd.current_energy), int(hd.max_energy)]
				energy_bar.max_value = hd.max_energy
				energy_bar.value = hd.current_energy
			else:
				energy_label.visible = false
				energy_bar.visible = false

		# Attributes
		if attribute_container:
			attribute_container.visible = true
			if points_label:
				points_label.text = "Attribute Points: %d" % hd.attribute_points
			if str_label:
				str_label.text = "STR: %d" % hd.strength
			if dex_label:
				dex_label.text = "DEX: %d" % hd.dexterity
			if int_label:
				int_label.text = "INT: %d" % hd.intelligence

			var can_spend: bool = hd.attribute_points > 0
			if str_plus_btn:
				str_plus_btn.disabled = not can_spend
			if dex_plus_btn:
				dex_plus_btn.disabled = not can_spend
			if int_plus_btn:
				int_plus_btn.disabled = not can_spend
	else:
		# Standard Unit (BaseUnit3D)
		if name_label:
			name_label.text = bound_unit.name
		var cur_hp: float = bound_unit.get("current_health") if "current_health" in bound_unit else 100.0
		var max_hp: float = bound_unit.get("max_health") if "max_health" in bound_unit else 100.0

		if hp_label and hp_bar:
			hp_label.text = "Health: %d / %d" % [int(cur_hp), int(max_hp)]
			hp_bar.max_value = max_hp
			hp_bar.value = cur_hp

		if shield_label and shield_bar:
			shield_label.visible = false
			shield_bar.visible = false
		if energy_label and energy_bar:
			energy_label.visible = false
			energy_bar.visible = false
		if attribute_container:
			attribute_container.visible = false

func _on_attribute_allocated(stat_name: String) -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		return

	if "hero_data" in bound_unit and bound_unit.hero_data != null:
		var hd: HeroData = bound_unit.hero_data
		hd.allocate_attribute(stat_name, 1)
		refresh_display()
