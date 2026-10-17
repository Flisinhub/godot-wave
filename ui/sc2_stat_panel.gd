class_name SC2StatPanel
extends PanelContainer

## Procedural StarCraft II Console / Unit Stat Panel UI.
## Displays holographic tactical wireframe, Health / Shield / Energy resource bars, and
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

# Vital Bar StyleBoxes for Dynamic Color Shifts
var _hp_fill_style: StyleBoxFlat
var _shield_fill_style: StyleBoxFlat
var _energy_fill_style: StyleBoxFlat
var _trough_style: StyleBoxFlat

# Attribute UI Elements
var attribute_container: VBoxContainer
var points_label: Label
var str_label: Label
var str_plus_btn: Button
var dex_label: Label
var dex_plus_btn: Button
var int_label: Label
var int_plus_btn: Button


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

	var h_split := HBoxContainer.new()
	h_split.custom_minimum_size = Vector2(460, 164)
	h_split.add_theme_constant_override("separation", 12)
	add_child(h_split)

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

	# Right: RPG Attributes Panel (STR, DEX, INT with [+] spend buttons)
	attribute_container = VBoxContainer.new()
	attribute_container.custom_minimum_size = Vector2(150, 160)
	attribute_container.add_theme_constant_override("separation", 4)

	points_label = Label.new()
	points_label.text = "Points: 0"
	points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	points_label.add_theme_font_size_override("font_size", 11)
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
	str_label.custom_minimum_size = Vector2(80, 24)
	str_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45, 1.0))
	str_label.add_theme_font_size_override("font_size", 11)
	str_row.add_child(str_label)

	str_plus_btn = Button.new()
	str_plus_btn.text = "[+]"
	str_plus_btn.custom_minimum_size = Vector2(32, 24)
	_apply_button_styles(str_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	str_plus_btn.pressed.connect(func(): _on_attribute_allocated("str"))
	str_row.add_child(str_plus_btn)
	attribute_container.add_child(str_row)

	# DEX row
	var dex_row := HBoxContainer.new()
	dex_label = Label.new()
	dex_label.text = "DEX: 10"
	dex_label.custom_minimum_size = Vector2(80, 24)
	dex_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55, 1.0))
	dex_label.add_theme_font_size_override("font_size", 11)
	dex_row.add_child(dex_label)

	dex_plus_btn = Button.new()
	dex_plus_btn.text = "[+]"
	dex_plus_btn.custom_minimum_size = Vector2(32, 24)
	_apply_button_styles(dex_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	dex_plus_btn.pressed.connect(func(): _on_attribute_allocated("dex"))
	dex_row.add_child(dex_plus_btn)
	attribute_container.add_child(dex_row)

	# INT row
	var int_row := HBoxContainer.new()
	int_label = Label.new()
	int_label.text = "INT: 10"
	int_label.custom_minimum_size = Vector2(80, 24)
	int_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	int_label.add_theme_font_size_override("font_size", 11)
	int_row.add_child(int_label)

	int_plus_btn = Button.new()
	int_plus_btn.text = "[+]"
	int_plus_btn.custom_minimum_size = Vector2(32, 24)
	_apply_button_styles(int_plus_btn, btn_normal, btn_hover, btn_pressed, btn_disabled)
	int_plus_btn.pressed.connect(func(): _on_attribute_allocated("int"))
	int_row.add_child(int_plus_btn)
	attribute_container.add_child(int_row)

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


## Refreshes real-time statistics, bars, and attribute allocation button states.
func refresh_display() -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		_clear_display()
		return

	if wireframe_rect and "bound_unit" in wireframe_rect:
		wireframe_rect.bound_unit = bound_unit

	var is_hero: bool = "hero_data" in bound_unit and bound_unit.hero_data != null

	if is_hero:
		var hd: HeroData = bound_unit.hero_data
		if name_label:
			name_label.text = "%s (Lvl %d)" % [hd.hero_name, hd.xp_level]

		# Health with dynamic green -> amber -> red shift
		if hp_label and hp_bar:
			hp_label.text = "Health: %d / %d" % [int(hd.current_hp), int(hd.max_hp)]
			hp_bar.max_value = hd.max_hp
			hp_bar.value = hd.current_hp
			_update_hp_bar_color(hd.current_hp, hd.max_hp)

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
		# Standard Unit (BaseUnit3D / Structure)
		if name_label:
			name_label.text = bound_unit.name
		var cur_hp: float = bound_unit.get("current_health") if "current_health" in bound_unit else 100.0
		var max_hp: float = bound_unit.get("max_health") if "max_health" in bound_unit else 100.0

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
		if attribute_container:
			attribute_container.visible = false


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

	if "hero_data" in bound_unit and bound_unit.hero_data != null:
		var hd: HeroData = bound_unit.hero_data
		hd.allocate_attribute(stat_name, 1)
		refresh_display()
