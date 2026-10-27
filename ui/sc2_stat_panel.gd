class_name SC2StatPanel
extends PanelContainer

## Procedural StarCraft II Console / Unit Stat Panel UI.
## Displays holographic tactical wireframe, Health / Shield / Energy resource bars, and
## RPG Attribute progression (STR / DEX / INT with [+] buttons and unspent points counter).
## Built with headless DisplayServer safety guards.

const HeroData = preload("res://core/heroes/hero_data.gd")
const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")

signal console_open_requested()

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

# Active Buffs Row (Task 4.17)
var active_buffs_scroll: ScrollContainer
var active_buffs_container: HBoxContainer

# Vital Bar StyleBoxes for Dynamic Color Shifts
var _hp_fill_style: StyleBoxFlat
var _shield_fill_style: StyleBoxFlat
var _energy_fill_style: StyleBoxFlat
var _trough_style: StyleBoxFlat

# Attribute UI Elements
var attribute_container: VBoxContainer
var combat_stats_label: Label
var points_label: Label
var str_label: Label
var str_plus_btn: Button
var dex_label: Label
var dex_plus_btn: Button
var int_label: Label
var int_plus_btn: Button
var end_label: Label
var end_plus_btn: Button
var console_btn: Button


## Inner class: Procedural Holographic Tactical Wireframe display.
class SC2WireframeDisplay extends ColorRect:
	var bound_unit: Node = null

	func _init() -> void:
		custom_minimum_size = Vector2(90, 110)
		color = Color(0.02, 0.04, 0.07, 0.95)

	func _process(_delta: float) -> void:
		if is_visible_in_tree() and DisplayServer.get_name() != "headless":
			queue_redraw()

	func _draw() -> void:
		if size.x <= 1 or size.y <= 1:
			return

		# 1. Background Diagnostic Grid
		var grid_step := 12.0
		var grid_col := Color(0.15, 0.35, 0.55, 0.22)
		var x := grid_step
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), grid_col, 1.0)
			x += grid_step
		var y := grid_step
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), grid_col, 1.0)
			y += grid_step

		# 2. Four Sci-Fi Corner Brackets [   ]
		var bracket_col := Color(0.3, 0.85, 1.0, 0.95)
		var b_len := 12.0
		var m := 4.0
		draw_line(Vector2(m, m), Vector2(m + b_len, m), bracket_col, 2.0)
		draw_line(Vector2(m, m), Vector2(m, m + b_len), bracket_col, 2.0)
		draw_line(Vector2(size.x - m, m), Vector2(size.x - m - b_len, m), bracket_col, 2.0)
		draw_line(Vector2(size.x - m, m), Vector2(size.x - m, m + b_len), bracket_col, 2.0)
		draw_line(Vector2(m, size.y - m), Vector2(m + b_len, size.y - m), bracket_col, 2.0)
		draw_line(Vector2(m, size.y - m), Vector2(m, size.y - m - b_len), bracket_col, 2.0)
		draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m - b_len, size.y - m), bracket_col, 2.0)
		draw_line(Vector2(size.x - m, size.y - m), Vector2(size.x - m, size.y - m - b_len), bracket_col, 2.0)

		# 3. Holographic Unit Vector Silhouette
		var center := size * 0.5
		if bound_unit != null and is_instance_valid(bound_unit):
			if bound_unit is StaticBody3D or "structure_name" in bound_unit:
				# Fortified Terran Structure: Outer hexagonal defense ring + reactor circle
				var struct_col := Color(0.2, 0.85, 1.0, 0.85)
				var hex_radius := 28.0
				var points := PackedVector2Array()
				for i in range(6):
					var angle := deg_to_rad(60.0 * i - 30.0)
					points.append(center + Vector2(cos(angle), sin(angle)) * hex_radius)
				for i in range(6):
					draw_line(points[i], points[(i + 1) % 6], struct_col, 1.5)
				draw_arc(center, 12.0, 0.0, TAU, 16, struct_col, 1.5)
				draw_line(center - Vector2(16, 0), center + Vector2(16, 0), struct_col, 1.0)
			else:
				# Infantry / Hero Marine Wireframe: Visor, Shoulders, Chest Armor, Gauss Rifle
				var marine_col := Color(0.25, 0.95, 0.45, 0.9)
				draw_arc(center - Vector2(0, 22), 10.0, 0.0, TAU, 16, marine_col, 1.5)
				draw_line(center - Vector2(6, 22), center + Vector2(6, 22), Color(0.4, 0.95, 1.0, 0.95), 2.5)
				draw_line(center - Vector2(26, 10), center - Vector2(12, 16), marine_col, 1.5)
				draw_line(center + Vector2(26, 10), center + Vector2(12, 16), marine_col, 1.5)
				draw_line(center - Vector2(26, 10), center - Vector2(22, 14), marine_col, 1.5)
				draw_line(center + Vector2(26, 10), center + Vector2(22, 14), marine_col, 1.5)
				draw_line(center - Vector2(16, 8), center + Vector2(16, 8), marine_col, 1.5)
				draw_line(center - Vector2(12, 22), center + Vector2(12, 22), marine_col, 1.5)
				draw_line(center - Vector2(16, 8), center - Vector2(12, 22), marine_col, 1.5)
				draw_line(center + Vector2(16, 8), center + Vector2(12, 22), marine_col, 1.5)
				draw_line(center + Vector2(12, 10), center + Vector2(28, 2), Color(0.3, 0.85, 1.0, 0.85), 2.0)
		else:
			# Standby Tactical Reticle
			var reticle_col := Color(0.25, 0.55, 0.8, 0.5)
			draw_arc(center, 20.0, 0.0, TAU, 24, reticle_col, 1.0)
			draw_line(center - Vector2(26, 0), center + Vector2(26, 0), reticle_col, 1.0)
			draw_line(center - Vector2(0, 26), center + Vector2(0, 26), reticle_col, 1.0)

		# 4. Animated Cyan Scanline Sweep
		if DisplayServer.get_name() != "headless":
			var sweep_y: float = fmod(Time.get_ticks_msec() * 0.05, size.y)
			draw_line(Vector2(4.0, sweep_y), Vector2(size.x - 4.0, sweep_y), Color(0.35, 0.9, 1.0, 0.35), 1.5)


func _init() -> void:
	custom_minimum_size = Vector2(480, 180)
	_build_ui_layout()


func _ready() -> void:
	_build_ui_layout()


func _build_ui_layout() -> void:
	if name_label != null:
		return

	# Style panel container with Terran steel translucent glass
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.065, 0.095, 0.92)
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.22, 0.48, 0.78, 0.75)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", panel_style)

	var v_main := VBoxContainer.new()
	v_main.add_theme_constant_override("separation", 3)
	add_child(v_main)

	# Dedicated horizontal bar atop the SC2StatPanel for Active Console Buffs (Task 4.17)
	active_buffs_scroll = ScrollContainer.new()
	active_buffs_scroll.custom_minimum_size = Vector2(460, 24)
	active_buffs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	active_buffs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	active_buffs_container = HBoxContainer.new()
	active_buffs_container.add_theme_constant_override("separation", 5)
	active_buffs_scroll.add_child(active_buffs_container)
	v_main.add_child(active_buffs_scroll)

	var h_split := HBoxContainer.new()
	h_split.custom_minimum_size = Vector2(460, 140)
	h_split.add_theme_constant_override("separation", 12)
	v_main.add_child(h_split)

	# Left: Wireframe / Portrait Box
	var left_box := VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(100, 160)

	wireframe_rect = SC2WireframeDisplay.new()
	left_box.add_child(wireframe_rect)

	name_label = Label.new()
	name_label.text = "No Unit Selected"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	name_label.add_theme_font_size_override("font_size", 11)
	left_box.add_child(name_label)
	h_split.add_child(left_box)

	# Initialize Vital Bar StyleBoxes
	_init_bar_styles()

	# Center: Triple Resource Bars (Health, Shield, Energy)
	var center_box := VBoxContainer.new()
	center_box.custom_minimum_size = Vector2(200, 160)
	center_box.add_theme_constant_override("separation", 3)

	# Health Bar
	hp_label = Label.new()
	hp_label.text = "Health: 0 / 0"
	hp_label.add_theme_color_override("font_color", Color(0.25, 0.95, 0.35, 1.0))
	hp_label.add_theme_font_size_override("font_size", 11)
	center_box.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(190, 18)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _trough_style)
	hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)
	center_box.add_child(hp_bar)

	# Shield Bar
	shield_label = Label.new()
	shield_label.text = "Shields: 0 / 0"
	shield_label.add_theme_color_override("font_color", Color(0.3, 0.82, 1.0, 1.0))
	shield_label.add_theme_font_size_override("font_size", 11)
	center_box.add_child(shield_label)

	shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(190, 16)
	shield_bar.show_percentage = false
	shield_bar.add_theme_stylebox_override("background", _trough_style)
	shield_bar.add_theme_stylebox_override("fill", _shield_fill_style)
	center_box.add_child(shield_bar)

	# Energy Bar
	energy_label = Label.new()
	energy_label.text = "Energy: 0 / 0"
	energy_label.add_theme_color_override("font_color", Color(0.88, 0.35, 1.0, 1.0))
	energy_label.add_theme_font_size_override("font_size", 11)
	center_box.add_child(energy_label)

	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(190, 16)
	energy_bar.show_percentage = false
	energy_bar.add_theme_stylebox_override("background", _trough_style)
	energy_bar.add_theme_stylebox_override("fill", _energy_fill_style)
	center_box.add_child(energy_bar)

	h_split.add_child(center_box)

	# Right: RPG Attributes Panel (STR, DEX, INT, END with [+] spend buttons)
	attribute_container = VBoxContainer.new()
	attribute_container.custom_minimum_size = Vector2(170, 160)
	attribute_container.add_theme_constant_override("separation", 2)

	combat_stats_label = Label.new()
	combat_stats_label.text = "DMG: 0 | ARM: 0 (+0 NA)"
	combat_stats_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
	combat_stats_label.add_theme_font_size_override("font_size", 10)
	attribute_container.add_child(combat_stats_label)

	points_label = Label.new()
	points_label.text = "Points: 0"
	points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	points_label.add_theme_font_size_override("font_size", 10)
	attribute_container.add_child(points_label)

	# Reusable Button Styles
	var btn_normal := _create_military_btn_style(Color(0.06, 0.10, 0.16, 0.95), Color(0.25, 0.55, 0.85, 0.8))
	var btn_hover := _create_military_btn_style(Color(0.10, 0.18, 0.28, 1.0), Color(0.40, 0.85, 1.0, 1.0))
	var btn_pressed := _create_military_btn_style(Color(0.20, 0.35, 0.50, 1.0), Color(1.0, 0.80, 0.20, 1.0))
	var btn_disabled := _create_military_btn_style(Color(0.03, 0.04, 0.06, 0.5), Color(0.12, 0.16, 0.22, 0.5))

	# STR row
	var str_row := HBoxContainer.new()
	str_label = Label.new()
	str_label.text = "STR: 10"
	str_label.custom_minimum_size = Vector2(85, 20)
	str_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45, 1.0))
	str_label.add_theme_font_size_override("font_size", 10)
	str_row.add_child(str_label)

	str_plus_btn = Button.new()
	str_plus_btn.text = "[+]"
	str_plus_btn.custom_minimum_size = Vector2(28, 20)
	_apply_button_styles(str_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	str_plus_btn.pressed.connect(func(): _on_attribute_allocated("str"))
	str_row.add_child(str_plus_btn)
	attribute_container.add_child(str_row)

	# DEX row
	var dex_row := HBoxContainer.new()
	dex_label = Label.new()
	dex_label.text = "DEX: 10"
	dex_label.custom_minimum_size = Vector2(85, 20)
	dex_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55, 1.0))
	dex_label.add_theme_font_size_override("font_size", 10)
	dex_row.add_child(dex_label)

	dex_plus_btn = Button.new()
	dex_plus_btn.text = "[+]"
	dex_plus_btn.custom_minimum_size = Vector2(28, 20)
	_apply_button_styles(dex_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	dex_plus_btn.pressed.connect(func(): _on_attribute_allocated("dex"))
	dex_row.add_child(dex_plus_btn)
	attribute_container.add_child(dex_row)

	# INT row
	var int_row := HBoxContainer.new()
	int_label = Label.new()
	int_label.text = "INT: 10"
	int_label.custom_minimum_size = Vector2(85, 20)
	int_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	int_label.add_theme_font_size_override("font_size", 10)
	int_row.add_child(int_label)

	int_plus_btn = Button.new()
	int_plus_btn.text = "[+]"
	int_plus_btn.custom_minimum_size = Vector2(28, 20)
	_apply_button_styles(int_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	int_plus_btn.pressed.connect(func(): _on_attribute_allocated("int"))
	int_row.add_child(int_plus_btn)
	attribute_container.add_child(int_row)

	# END row
	var end_row := HBoxContainer.new()
	end_label = Label.new()
	end_label.text = "END: 10"
	end_label.custom_minimum_size = Vector2(85, 20)
	end_label.add_theme_color_override("font_color", Color(0.9, 0.65, 0.35, 1.0))
	end_label.add_theme_font_size_override("font_size", 10)
	end_row.add_child(end_label)

	end_plus_btn = Button.new()
	end_plus_btn.text = "[+]"
	end_plus_btn.custom_minimum_size = Vector2(28, 20)
	_apply_button_styles(end_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	end_plus_btn.pressed.connect(func(): _on_attribute_allocated("end"))
	end_row.add_child(end_plus_btn)
	attribute_container.add_child(end_row)

	console_btn = Button.new()
	console_btn.text = "⚡ CONSOLA (Alt+C)"
	console_btn.custom_minimum_size = Vector2(130, 22)
	_apply_button_styles(console_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	console_btn.add_theme_font_size_override("font_size", 10)
	console_btn.pressed.connect(func(): console_open_requested.emit())
	attribute_container.add_child(console_btn)

	h_split.add_child(attribute_container)

	_clear_display()


func _init_bar_styles() -> void:
	# Indented dark trough background
	_trough_style = StyleBoxFlat.new()
	_trough_style.bg_color = Color(0.02, 0.03, 0.05, 0.95)
	_trough_style.border_width_top = 1
	_trough_style.border_width_bottom = 1
	_trough_style.border_width_left = 1
	_trough_style.border_width_right = 1
	_trough_style.border_color = Color(0.18, 0.28, 0.40, 0.85)
	_trough_style.corner_radius_top_left = 2
	_trough_style.corner_radius_top_right = 2
	_trough_style.corner_radius_bottom_left = 2
	_trough_style.corner_radius_bottom_right = 2

	# Health fill style
	_hp_fill_style = StyleBoxFlat.new()
	_hp_fill_style.bg_color = Color(0.12, 0.85, 0.22, 1.0)
	_hp_fill_style.corner_radius_top_left = 2
	_hp_fill_style.corner_radius_top_right = 2
	_hp_fill_style.corner_radius_bottom_left = 2
	_hp_fill_style.corner_radius_bottom_right = 2

	# Shield fill style: Plasma cyan
	_shield_fill_style = StyleBoxFlat.new()
	_shield_fill_style.bg_color = Color(0.18, 0.78, 1.0, 1.0)
	_shield_fill_style.corner_radius_top_left = 2
	_shield_fill_style.corner_radius_top_right = 2
	_shield_fill_style.corner_radius_bottom_left = 2
	_shield_fill_style.corner_radius_bottom_right = 2

	# Energy fill style: Psionic magenta/violet
	_energy_fill_style = StyleBoxFlat.new()
	_energy_fill_style.bg_color = Color(0.85, 0.25, 0.95, 1.0)
	_energy_fill_style.corner_radius_top_left = 2
	_energy_fill_style.corner_radius_top_right = 2
	_energy_fill_style.corner_radius_bottom_left = 2
	_energy_fill_style.corner_radius_bottom_right = 2


func _create_military_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_color = border
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s


func _apply_button_styles(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, disabled: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.5, 0.5))


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
	if active_buffs_container:
		for c in active_buffs_container.get_children():
			c.queue_free()
	if wireframe_rect and "bound_unit" in wireframe_rect:
		wireframe_rect.bound_unit = null


## Binds a selected unit to this stat console.
func bind_unit(unit: Node) -> void:
	bound_unit = unit
	if wireframe_rect and "bound_unit" in wireframe_rect:
		wireframe_rect.bound_unit = unit
	if unit == null or not is_instance_valid(unit):
		_clear_display()
		return

	refresh_display()


## Refreshes real-time statistics, bars, active buffs, and attribute allocation button states.
func refresh_display() -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		_clear_display()
		return

	if wireframe_rect and "bound_unit" in wireframe_rect:
		wireframe_rect.bound_unit = bound_unit

	var is_hero: bool = "hero_data" in bound_unit and bound_unit.hero_data != null
	var stats_comp: StatsComponent = bound_unit.get_node_or_null("StatsComponent") as StatsComponent
	var buff_comp: BuffComponent = bound_unit.get_node_or_null("BuffComponent") as BuffComponent

	var econ: SFEEconomyManager = null
	if is_inside_tree():
		var tree := get_tree()
		if tree and tree.root:
			econ = tree.root.find_child("EconomyManager", true, false) as SFEEconomyManager

	if is_hero:
		var hd: HeroData = bound_unit.hero_data
		if name_label:
			name_label.text = "%s (Lvl %d)" % [hd.hero_name, hd.xp_level]

		var cur_hp: float = bound_unit.current_health if "current_health" in bound_unit else hd.current_hp
		var max_hp_val: float = stats_comp.get_effective_max_hp() if stats_comp else hd.max_hp
		if hp_label and hp_bar:
			hp_label.text = "Health: %d / %d" % [int(cur_hp), int(max_hp_val)]
			hp_bar.max_value = max_hp_val
			hp_bar.value = cur_hp
			_update_hp_bar_color(cur_hp, max_hp_val)

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
			var max_eng: float = stats_comp.get_effective_max_energy() if stats_comp else hd.max_energy
			if max_eng > 0.0:
				energy_label.visible = true
				energy_bar.visible = true
				energy_label.text = "Energy: %d / %d" % [int(hd.current_energy), int(max_eng)]
				energy_bar.max_value = max_eng
				energy_bar.value = hd.current_energy
			else:
				energy_label.visible = false
				energy_bar.visible = false

		# Attributes & Combat Stats
		if attribute_container:
			attribute_container.visible = true
			if stats_comp:
				if combat_stats_label:
					combat_stats_label.text = "DMG: %.1f | ARM: %.1f (+%.1f NA)" % [
						stats_comp.get_effective_damage(),
						stats_comp.get_effective_armor(),
						stats_comp.get_neutron_armor_mitigation()
					]
				if points_label:
					var pt_str := (" | Ptos: %d" % hd.attribute_points) if hd.attribute_points > 0 else ""
					points_label.text = "💎 %d%s" % [econ.current_minerals if econ else 0, pt_str]

				_update_attr_row("strength", "STR", stats_comp, hd, econ, str_label, str_plus_btn)
				_update_attr_row("dexterity", "DEX", stats_comp, hd, econ, dex_label, dex_plus_btn)
				_update_attr_row("intelligence", "INT", stats_comp, hd, econ, int_label, int_plus_btn)
				_update_attr_row("endurance", "END", stats_comp, hd, econ, end_label, end_plus_btn)
			else:
				if points_label:
					points_label.text = "Attribute Points: %d" % hd.attribute_points
				if str_label: str_label.text = "STR: %d" % hd.strength
				if dex_label: dex_label.text = "DEX: %d" % hd.dexterity
				if int_label: int_label.text = "INT: %d" % hd.intelligence
				if end_label: end_label.text = "END: %d" % hd.endurance

				var can_spend: bool = hd.attribute_points > 0
				if str_plus_btn: str_plus_btn.disabled = not can_spend
				if dex_plus_btn: dex_plus_btn.disabled = not can_spend
				if int_plus_btn: int_plus_btn.disabled = not can_spend
				if end_plus_btn: end_plus_btn.disabled = not can_spend
	else:
		# Standard Unit (BaseUnit3D / Structure)
		if name_label:
			name_label.text = bound_unit.name
		var cur_hp: float = bound_unit.get("current_health") if "current_health" in bound_unit else 100.0
		var max_hp: float = stats_comp.get_effective_max_hp() if stats_comp else (bound_unit.get("max_health") if "max_health" in bound_unit else 100.0)

		if hp_label and hp_bar:
			hp_label.text = "Health: %d / %d" % [int(cur_hp), int(max_hp)]
			hp_bar.max_value = max_hp
			hp_bar.value = cur_hp
			_update_hp_bar_color(cur_hp, max_hp)

		if shield_label and shield_bar:
			shield_label.visible = false
			shield_bar.visible = false
		if energy_label and energy_bar:
			energy_label.visible = false
			energy_bar.visible = false

		if stats_comp and attribute_container:
			attribute_container.visible = true
			if combat_stats_label:
				combat_stats_label.text = "DMG: %.1f | ARM: %.1f" % [
					stats_comp.get_effective_damage(),
					stats_comp.get_effective_armor()
				]
			if points_label:
				points_label.text = "Minerales: %d 💎" % (econ.current_minerals if econ else 0)
			_update_attr_row("strength", "STR", stats_comp, null, econ, str_label, str_plus_btn)
			_update_attr_row("dexterity", "DEX", stats_comp, null, econ, dex_label, dex_plus_btn)
			_update_attr_row("intelligence", "INT", stats_comp, null, econ, int_label, int_plus_btn)
			_update_attr_row("endurance", "END", stats_comp, null, econ, end_label, end_plus_btn)
		elif attribute_container:
			attribute_container.visible = false

	# Refresh Active Buff Icons Row (Task 4.17)
	_refresh_active_buffs(buff_comp)


func _update_attr_row(
	attr_id: String,
	display_name: String,
	stats_comp: StatsComponent,
	hd: HeroData,
	econ: SFEEconomyManager,
	lbl: Label,
	btn: Button
) -> void:
	if not stats_comp:
		return
	var val: int = stats_comp.get_attribute_value(attr_id)
	var cost: int = stats_comp.get_next_attribute_cost(attr_id)
	if lbl:
		lbl.text = "%s: %d" % [display_name, val]
	if btn:
		var can_spend: bool = (hd != null and hd.attribute_points > 0) or (econ != null and econ.current_minerals >= cost)
		btn.disabled = not can_spend
		btn.tooltip_text = "+1 %s\nCoste: %d 💎%s" % [
			display_name,
			cost,
			" (o 1 Pto disponible)" if (hd != null and hd.attribute_points > 0) else ""
		]


func _refresh_active_buffs(buff_comp: BuffComponent) -> void:
	if not active_buffs_container:
		return

	# Clear old badges
	for child in active_buffs_container.get_children():
		child.queue_free()

	if not buff_comp:
		return

	# 1. Tier 1 to 7 active buffs (including Predator)
	for tier in buff_comp.active_tier_buffs.keys():
		var b_data: Dictionary = buff_comp.active_tier_buffs[tier]
		var b_name: String = b_data.get("name", "Buff")
		var b_id: String = b_data.get("id", "")
		if b_name.to_lower().contains("predator") or b_id.to_lower().contains("predator"):
			_create_buff_badge("Predator", Color(1.0, 0.35, 0.2), "Predator: +100% Daño contra Jefes y Élite")
		else:
			_create_buff_badge("T%d: %s" % [tier, b_name.left(8)], Color(0.25, 0.85, 1.0), "Tier %d: %s" % [tier, b_name])

	# 2. Supreme Buffs (Ace, Demiurge, Max XP)
	if buff_comp.supreme_buffs.get("ace", false) or buff_comp.is_ace_active:
		_create_buff_badge("★ ACE", Color(1.0, 0.82, 0.15), "Ace Supremo: +50% Daño Total")
	if buff_comp.supreme_buffs.get("demiurge", false):
		var cd_text := "Listo" if buff_comp.demiurge_cooldown_timer <= 0.0 else "CD: %ds" % int(ceilf(buff_comp.demiurge_cooldown_timer))
		_create_buff_badge("★ DEMIURGE [%s]" % cd_text, Color(0.2, 0.95, 0.7), "Demiurge: Previene muerte (180s CD)")
	if buff_comp.supreme_buffs.get("maxima_experiencia", false):
		_create_buff_badge("★ MAX XP", Color(0.85, 0.45, 1.0), "Máxima Experiencia: Nivel 100")

	# 3. Dynamic Condition Stacks & Stances
	if buff_comp.is_camouflaged:
		_create_buff_badge("Optical Lens [Camuflado]", Color(0.65, 0.4, 1.0), "Optical Lens: Camuflaje táctico activo")
	if buff_comp.momentum_stacks > 0:
		_create_buff_badge("Momentum [x%d]" % buff_comp.momentum_stacks, Color(0.3, 0.95, 0.4), "Momentum: %d stacks (+%d%% Daño)" % [buff_comp.momentum_stacks, buff_comp.momentum_stacks * 5])
	if buff_comp.static_charge_stacks > 0:
		_create_buff_badge("Static Charge [x%d]" % buff_comp.static_charge_stacks, Color(1.0, 0.9, 0.25), "Static Charge: %d stacks" % buff_comp.static_charge_stacks)
	if buff_comp.bulwark_stacks > 0:
		_create_buff_badge("Bulwark [x%d]" % buff_comp.bulwark_stacks, Color(0.4, 0.75, 1.0), "Bulwark: %d stacks (-%d%% Daño)" % [buff_comp.bulwark_stacks, buff_comp.bulwark_stacks * 5])


func get_active_buff_texts() -> Array[String]:
	var result: Array[String] = []
	if active_buffs_container:
		for child in active_buffs_container.get_children():
			if child is Label:
				result.append(child.text)
	return result


func _create_buff_badge(text: String, border_color: Color, tooltip: String) -> void:
	var badge := Label.new()
	badge.text = text
	badge.tooltip_text = tooltip
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(border_color.r * 0.15, border_color.g * 0.15, border_color.b * 0.15, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("panel", style)
	active_buffs_container.add_child(badge)


func _update_hp_bar_color(cur_hp: float, max_hp: float) -> void:
	if _hp_fill_style == null:
		return
	var ratio: float = cur_hp / maxf(1.0, max_hp)
	if ratio <= 0.25:
		_hp_fill_style.bg_color = Color(0.95, 0.20, 0.15, 1.0) # Critical Red
	elif ratio <= 0.50:
		_hp_fill_style.bg_color = Color(0.95, 0.75, 0.10, 1.0) # Amber / Yellow
	else:
		_hp_fill_style.bg_color = Color(0.12, 0.85, 0.22, 1.0) # Terran Vital Green


func _on_attribute_allocated(stat_name: String) -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		return

	var stats_comp: StatsComponent = bound_unit.get_node_or_null("StatsComponent") as StatsComponent
	var econ: SFEEconomyManager = null
	if is_inside_tree():
		var tree := get_tree()
		if tree and tree.root:
			econ = tree.root.find_child("EconomyManager", true, false) as SFEEconomyManager

	if stats_comp:
		var cost := stats_comp.get_next_attribute_cost(stat_name)
		if "hero_data" in bound_unit and bound_unit.hero_data != null and bound_unit.hero_data.attribute_points > 0:
			bound_unit.hero_data.attribute_points -= 1
			stats_comp.invest_attribute(stat_name, 1)
			_sync_hero_data_attributes()
			refresh_display()
			return

		if econ and econ.current_minerals >= cost:
			if econ.spend_minerals(cost):
				stats_comp.invest_attribute(stat_name, 1)
				_sync_hero_data_attributes()
				refresh_display()
				return
	elif "hero_data" in bound_unit and bound_unit.hero_data != null:
		var hd: HeroData = bound_unit.hero_data
		hd.allocate_attribute(stat_name, 1)
		refresh_display()


func _sync_hero_data_attributes() -> void:
	if bound_unit and "hero_data" in bound_unit and bound_unit.hero_data != null:
		var stats_comp: StatsComponent = bound_unit.get_node_or_null("StatsComponent") as StatsComponent
		if stats_comp:
			bound_unit.hero_data.strength = stats_comp.strength
			bound_unit.hero_data.dexterity = stats_comp.dexterity
			bound_unit.hero_data.intelligence = stats_comp.intelligence
			bound_unit.hero_data.endurance = stats_comp.endurance
			bound_unit.hero_data.recalculate_derived_stats(false)
