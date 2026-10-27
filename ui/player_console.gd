class_name PlayerConsole
extends CanvasLayer

## PlayerConsole - SFE5 In-Game RPG Upgrade & Buff Console (Tasks 4.1 - 4.5).
## Opened via Alt+C. Allows purchasing RPG Attributes (STR/DEX/INT/END),
## Tier 1-7 Buffs, Supreme Buffs (Ace, Demiurge, Max Exp), and Racial Upgrades.
## Supports Shift+Click to invest all remaining minerals.

const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const GameConfig = preload("res://core/game_config.gd")

var target_unit: Node = null
var stats_comp: StatsComponent = null
var buff_comp: BuffComponent = null
var economy_manager: SFEEconomyManager = null

# UI Root Containers
var root_panel: PanelContainer = null
var tab_container: TabContainer = null
var minerals_lbl: Label = null
var target_name_lbl: Label = null

# Attribute UI Elements
var attr_labels: Dictionary = {}
var attr_buttons: Dictionary = {}

signal console_opened()
signal console_closed()
signal attribute_purchased(attr_name: String, points: int)
signal buff_purchased(tier: int, buff_id: String)


func _ready() -> void:
	layer = 110 # Above gameplay, below victory modals
	visible = false
	_build_console_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.alt_pressed and event.keycode == KEY_C:
			toggle_console()
		elif event.keycode == KEY_ESCAPE and visible:
			close_console()


func toggle_console() -> void:
	if visible:
		close_console()
	else:
		open_console()


func open_console(unit: Node = null) -> void:
	if unit:
		target_unit = unit
	elif target_unit == null:
		# Locate active hero if none specified
		var heroes := get_tree().get_nodes_in_group("heroes")
		if not heroes.is_empty():
			target_unit = heroes[0]
	
	_resolve_components()
	_refresh_all_tabs()
	visible = true
	console_opened.emit()


func close_console() -> void:
	visible = false
	console_closed.emit()


func _resolve_components() -> void:
	if target_unit:
		stats_comp = target_unit.get_node_or_null("StatsComponent") as StatsComponent
		if not stats_comp:
			# Auto-create if unit doesn't have one attached yet
			stats_comp = StatsComponent.new()
			stats_comp.name = "StatsComponent"
			target_unit.add_child(stats_comp)
		
		buff_comp = target_unit.get_node_or_null("BuffComponent") as BuffComponent
		if not buff_comp:
			buff_comp = BuffComponent.new()
			buff_comp.name = "BuffComponent"
			target_unit.add_child(buff_comp)
	
	if not economy_manager:
		var econ = get_tree().root.find_child("EconomyManager", true, false)
		if econ is SFEEconomyManager:
			economy_manager = econ


func _build_console_ui() -> void:
	var root := Control.new()
	root.name = "ConsoleRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	
	# Backdrop Dim
	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.01, 0.02, 0.05, 0.75)
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg_dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	root_panel = PanelContainer.new()
	root_panel.custom_minimum_size = Vector2(720, 520)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.13, 0.98)
	style.border_color = Color(0.2, 0.55, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	root_panel.add_theme_stylebox_override("panel", style)
	center.add_child(root_panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	root_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Top Header Bar
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	target_name_lbl = Label.new()
	target_name_lbl.text = "CONSOLA DEL JUGADOR — [JIM RAYNOR]"
	target_name_lbl.add_theme_font_size_override("font_size", 18)
	target_name_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	header.add_child(target_name_lbl)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	minerals_lbl = Label.new()
	minerals_lbl.text = "💎 12,000"
	minerals_lbl.add_theme_font_size_override("font_size", 16)
	minerals_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	header.add_child(minerals_lbl)
	
	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(close_console)
	header.add_child(close_btn)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Tab Container (Atributos, Bufos, Raza, Unidad)
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)
	
	_build_attributes_tab()
	_build_buffs_tab()
	_build_racial_tab()


func _build_attributes_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Atributos"
	tab.add_theme_constant_override("separation", 14)
	tab_container.add_child(tab)
	
	var hint_lbl := Label.new()
	hint_lbl.text = "💡 Consejo: Mantén SHIFT y haz clic para invertir TODO tu mineral restante en un atributo."
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	tab.add_child(hint_lbl)
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	tab.add_child(grid)
	
	_add_attribute_row(grid, "strength", "Fuerza", "+15 Vida, +0.8 Daño Físico")
	_add_attribute_row(grid, "dexterity", "Destreza", "+1.2% Vel. Ataque, +0.7 Daño")
	_add_attribute_row(grid, "intelligence", "Inteligencia", "+10 Energía, +0.25 Reg/s, +1.5% AP")
	_add_attribute_row(grid, "endurance", "Aguante", "+0.12 Armadura, +0.35 Reg/s")
	
	var sep := HSeparator.new()
	tab.add_child(sep)
	
	# Neutron Armor Upgrade (Task 4.10)
	var na_box := HBoxContainer.new()
	tab.add_child(na_box)
	
	var na_info := Label.new()
	na_info.name = "NeutronArmorLabel"
	na_info.text = "Neutron Armor (Nivel 0): +0.0 Mitigación plana contra todo daño"
	na_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	na_box.add_child(na_info)
	
	var na_btn := Button.new()
	na_btn.name = "NeutronArmorBtn"
	na_btn.text = "Mejorar (250 💎)"
	na_btn.pressed.connect(_on_neutron_armor_pressed)
	na_box.add_child(na_btn)


func _add_attribute_row(grid: GridContainer, attr_id: String, attr_title: String, desc: String) -> void:
	var title_lbl := Label.new()
	title_lbl.text = attr_title
	title_lbl.custom_minimum_size = Vector2(100, 0)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	grid.add_child(title_lbl)
	
	var val_lbl := Label.new()
	val_lbl.text = "0 pts"
	val_lbl.name = attr_id + "_val"
	val_lbl.custom_minimum_size = Vector2(60, 0)
	attr_labels[attr_id] = val_lbl
	grid.add_child(val_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.custom_minimum_size = Vector2(300, 0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	grid.add_child(desc_lbl)
	
	var buy_btn := Button.new()
	buy_btn.text = "+1 (50 💎)"
	buy_btn.custom_minimum_size = Vector2(120, 32)
	attr_buttons[attr_id] = buy_btn
	buy_btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var is_shift: bool = event.shift_pressed
			_on_attribute_clicked(attr_id, is_shift)
	)
	grid.add_child(buy_btn)


func _build_buffs_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Bufos de Consola"
	tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(tab)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	
	# Tier 1 to 7 Buffs + Supreme Buffs
	_add_buff_entry(list, 1, "optical_lens", "Optical Lens", "Camuflaje pasivo si no recibes daño durante 2s", 250)
	_add_buff_entry(list, 2, "hardened_carapace", "Hardened Carapace", "+3 Armadura plana y +5 HP/s regeneración", 400)
	_add_buff_entry(list, 3, "momentum", "Momentum", "Acumula hasta 5 cargas moviéndote (+5% daño por carga)", 750)
	_add_buff_entry(list, 3, "predator", "Predator", "+100% daño vs Heroicos (+150% tras 5s sin daño)", 850)
	_add_buff_entry(list, 4, "static_charge", "Static Charge", "Hasta 10 cargas pasivas (+1% daño, +2 reg energía/s)", 1200)
	_add_buff_entry(list, 6, "bulwark", "Bulwark / Braced", "+5% reducción de daño acumulable hasta 25% estando quieto", 2000)
	
	# Supreme Buffs
	var sup_header := Label.new()
	sup_header.text = "— BUFOS SUPREMOS (ACE, DEMIURGE, MÁXIMA EXPERIENCIA) —"
	sup_header.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	list.add_child(sup_header)
	
	_add_supreme_entry(list, "ace", "Ace (As)", "Poder supremo de combate: +50% daño global total", 5000)
	_add_supreme_entry(list, "demiurge", "Demiurge", "Evita una muerte fatal y recupera 35% HP (enfriamiento: 180s)", 7500)
	_add_supreme_entry(list, "maxima_experiencia", "Máxima Experiencia", "Sube instantáneamente a Nivel 100 (Reembolsa 750 💎 por cada nivel actual)", 75000)


func _add_buff_entry(container: VBoxContainer, tier: int, buff_id: String, buff_name: String, desc: String, cost: int) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)
	
	var t_lbl := Label.new()
	t_lbl.text = "[T%d]" % tier
	t_lbl.custom_minimum_size = Vector2(40, 0)
	t_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	row.add_child(t_lbl)
	
	var name_lbl := Label.new()
	name_lbl.text = buff_name
	name_lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(name_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	row.add_child(desc_lbl)
	
	var btn := Button.new()
	btn.text = "Equipar (%d 💎)" % cost
	btn.custom_minimum_size = Vector2(130, 28)
	btn.pressed.connect(func(): _on_buy_buff_pressed(tier, buff_id, buff_name, cost))
	row.add_child(btn)


func _add_supreme_entry(container: VBoxContainer, buff_id: String, buff_name: String, desc: String, cost: int) -> void:
	var row := HBoxContainer.new()
	container.add_child(row)
	
	var t_lbl := Label.new()
	t_lbl.text = "[⭐]"
	t_lbl.custom_minimum_size = Vector2(40, 0)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	row.add_child(t_lbl)
	
	var name_lbl := Label.new()
	name_lbl.text = buff_name
	name_lbl.custom_minimum_size = Vector2(160, 0)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row.add_child(name_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	row.add_child(desc_lbl)
	
	var btn := Button.new()
	btn.text = "Comprar (%d 💎)" % cost
	btn.custom_minimum_size = Vector2(140, 28)
	btn.pressed.connect(func(): _on_buy_supreme_pressed(buff_id, cost))
	row.add_child(btn)


func _build_racial_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Mejoras Raciales"
	tab.add_theme_constant_override("separation", 10)
	tab_container.add_child(tab)
	
	var lbl := Label.new()
	lbl.text = "Mejoras de Balística, Armadura de Infantería y Ópticas de Plasma Terran"
	tab.add_child(lbl)


func _refresh_all_tabs() -> void:
	if economy_manager:
		minerals_lbl.text = "💎 %d" % economy_manager.current_minerals
	
	if stats_comp:
		for attr in ["strength", "dexterity", "intelligence", "endurance"]:
			var pts := stats_comp.get_attribute_value(attr)
			var cost := stats_comp.get_next_attribute_cost(attr)
			if attr_labels.has(attr):
				attr_labels[attr].text = "%d pts" % pts
			if attr_buttons.has(attr):
				attr_buttons[attr].text = "+1 (%d 💎)" % cost
		
		var na_lbl := root_panel.find_child("NeutronArmorLabel", true, false) as Label
		var na_btn := root_panel.find_child("NeutronArmorBtn", true, false) as Button
		if na_lbl and na_btn:
			na_lbl.text = "Neutron Armor (Nivel %d): +%.1f Mitigación plana contra todo daño" % [
				stats_comp.neutron_armor_level,
				stats_comp.get_neutron_armor_mitigation()
			]
			na_btn.text = "Mejorar (%d 💎)" % stats_comp.get_next_neutron_armor_cost()


func _on_attribute_clicked(attr_id: String, is_shift: bool) -> void:
	if not stats_comp or not economy_manager:
		return
	
	var available_minerals := economy_manager.current_minerals
	if is_shift:
		# Shift+Click: Invest all available minerals! (Task 4.5)
		var res := stats_comp.invest_max_possible(attr_id, available_minerals)
		var spent: int = res.get("total_spent", 0)
		var bought: int = res.get("points_bought", 0)
		if spent > 0:
			economy_manager.spend_minerals(spent)
			attribute_purchased.emit(attr_id, bought)
	else:
		# Single point purchase
		var cost := stats_comp.get_next_attribute_cost(attr_id)
		if available_minerals >= cost:
			if economy_manager.spend_minerals(cost):
				stats_comp.invest_attribute(attr_id, 1)
				attribute_purchased.emit(attr_id, 1)
	
	_refresh_all_tabs()


func _on_neutron_armor_pressed() -> void:
	if not stats_comp or not economy_manager:
		return
	var cost := stats_comp.get_next_neutron_armor_cost()
	if economy_manager.current_minerals >= cost:
		if economy_manager.spend_minerals(cost):
			stats_comp.upgrade_neutron_armor()
			_refresh_all_tabs()


func _on_buy_buff_pressed(tier: int, buff_id: String, buff_name: String, cost: int) -> void:
	if not buff_comp or not economy_manager:
		return
	if economy_manager.current_minerals < cost:
		return
	
	if economy_manager.spend_minerals(cost):
		var res := buff_comp.equip_tier_buff(tier, buff_id, buff_name, cost)
		var refund: int = res.get("refund", 0)
		if refund > 0:
			economy_manager.add_minerals(refund)
		buff_purchased.emit(tier, buff_id)
		_refresh_all_tabs()


func _on_buy_supreme_pressed(buff_id: String, cost: int) -> void:
	if not buff_comp or not economy_manager:
		return
	
	if buff_id == "ace":
		if economy_manager.current_minerals >= cost and economy_manager.spend_minerals(cost):
			buff_comp.unlock_ace()
	elif buff_id == "demiurge":
		if economy_manager.current_minerals >= cost and economy_manager.spend_minerals(cost):
			buff_comp.unlock_demiurge()
	elif buff_id == "maxima_experiencia":
		var hero_lvl := 1
		if target_unit and "level" in target_unit:
			hero_lvl = target_unit.level
		var res := buff_comp.purchase_maxima_experiencia(hero_lvl, economy_manager.current_minerals)
		if res.get("success", false):
			var actual_cost: int = res.get("cost", cost)
			economy_manager.spend_minerals(actual_cost)
			if target_unit and "level" in target_unit:
				target_unit.level = 100
	
	_refresh_all_tabs()
