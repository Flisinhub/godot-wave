class_name PlayerConsole
extends CanvasLayer

## PlayerConsole - SFE5 In-Game RPG Upgrade & Buff Console (Tasks 4.1 - 4.5).
## Opened via Alt+C. Allows purchasing RPG Attributes (STR/DEX/INT/END),
## Tier 1-7 Buffs, Supreme Buffs (Ace, Demiurge, Max Exp), and Racial Upgrades.
## Supports Shift+Click to invest all remaining minerals.

const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const EliteComponent = preload("res://core/components/elite_component.gd")
const UnitRecruitmentManager = preload("res://core/recruitment/unit_recruitment_manager.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const GameConfig = preload("res://core/game_config.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")

var target_unit: Node = null
var stats_comp: StatsComponent = null
var buff_comp: BuffComponent = null
var elite_comp: EliteComponent = null
var economy_manager: SFEEconomyManager = null
var allow_buff_purchase: bool = true

# UI Root Containers
var root_panel: PanelContainer = null
var tab_container: TabContainer = null
var minerals_lbl: Label = null
var target_name_lbl: Label = null

# Attribute UI Elements
var attr_labels: Dictionary = {}
var attr_buttons: Dictionary = {}

# Racial & Unit-Specific Upgrades (Tasks 4.8, 4.9)
const RACIAL_UPGRADE_DEFS: Dictionary = {
	"weapon_damage": {
		"title": "Daño de Armas / Balística",
		"desc": "+3.0 Daño base y +5% Daño total por nivel",
		"base_cost": 100,
		"growth": 1.15,
		"max_lvl": 30
	},
	"armor_plating": {
		"title": "Blindaje de Infantería",
		"desc": "+1.0 Armadura plana por nivel",
		"base_cost": 120,
		"growth": 1.15,
		"max_lvl": 30
	},
	"bio_vitality": {
		"title": "Bio-Ingeniería / Vitalidad",
		"desc": "+50.0 Vida máxima por nivel",
		"base_cost": 150,
		"growth": 1.20,
		"max_lvl": 20
	},
	"plasma_reactor": {
		"title": "Reactor / Ópticas Plasma",
		"desc": "+25 Energía máx y +0.25 Reg/s por nivel",
		"base_cost": 200,
		"growth": 1.20,
		"max_lvl": 15
	},
	"attack_speed": {
		"title": "Aceleración de Disparo",
		"desc": "+4% Velocidad de ataque por nivel",
		"base_cost": 175,
		"growth": 1.18,
		"max_lvl": 20
	},
	"unit_gauss": {
		"title": "Cadencia Gauss (Marine/Raynor)",
		"desc": "+15% Cadencia y +2 Daño balístico",
		"base_cost": 250,
		"growth": 1.35,
		"max_lvl": 5
	},
	"unit_concussion": {
		"title": "Proyectil Conmocionador (Marauder)",
		"desc": "Ralentiza 25% y otorga +25 Vida",
		"base_cost": 300,
		"growth": 1.35,
		"max_lvl": 5
	},
	"unit_cloak": {
		"title": "Reactor Ocular (Ghost/Nova)",
		"desc": "+30 Energía máx y +1.5 Rango ataque",
		"base_cost": 350,
		"growth": 1.35,
		"max_lvl": 5
	},
	"unit_void_blade": {
		"title": "Hojas de Vacío (Zeratul)",
		"desc": "+8 Daño cuerpo a cuerpo y +10% Vel. movimiento",
		"base_cost": 400,
		"growth": 1.35,
		"max_lvl": 5
	},
	"unit_storm": {
		"title": "Sobrecarga Psiónica (Tassadar)",
		"desc": "+20% Poder de habilidad (AP) y +15 Escudo máx",
		"base_cost": 400,
		"growth": 1.35,
		"max_lvl": 5
	},
	"unit_nano": {
		"title": "Nano-Inyectores (Medic/Stetmann)",
		"desc": "+30% Rango curativo y +150 Vida de aura",
		"base_cost": 300,
		"growth": 1.35,
		"max_lvl": 5
	}
}

var racial_levels: Dictionary = {
	"weapon_damage": 0,
	"armor_plating": 0,
	"bio_vitality": 0,
	"plasma_reactor": 0,
	"attack_speed": 0,
	"unit_gauss": 0,
	"unit_concussion": 0,
	"unit_cloak": 0,
	"unit_void_blade": 0,
	"unit_storm": 0,
	"unit_nano": 0
}
var racial_labels: Dictionary = {}
var racial_buttons: Dictionary = {}

# Recruitment & Elite Elements (Fase 6)
var elite_info_lbl: Label = null
var elite_upgrade_btn: Button = null
var supply_lbl: Label = null
var recruit_buttons: Dictionary = {}

signal console_opened()
signal console_closed()
signal attribute_purchased(attr_name: String, points: int)
signal buff_purchased(tier: int, buff_id: String)
signal racial_upgrade_purchased(upgrade_id: String, new_level: int)
signal unit_recruited(unit: Node, cost: int)


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


func open_console(unit: Node = null, tab_index: int = -1) -> void:
	if unit:
		target_unit = unit
	elif target_unit == null:
		# Locate active hero if none specified
		var heroes := get_tree().get_nodes_in_group("heroes")
		if not heroes.is_empty():
			target_unit = heroes[0]
	
	_resolve_components()
	_refresh_all_tabs()
	if tab_index >= 0 and tab_container and tab_index < tab_container.get_tab_count():
		tab_container.current_tab = tab_index
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
		
		elite_comp = target_unit.get_node_or_null("EliteComponent") as EliteComponent
		if not elite_comp and target_unit.has_method("_ensure_elite_component"):
			elite_comp = target_unit._ensure_elite_component()
	
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
	_build_recruitment_tab()


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

	var hint := Label.new()
	hint.text = "💡 Clic: +1 Nivel  |  Ctrl+Clic: +5 Niveles  |  Shift+Clic: Invertir TODO"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	tab.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	# 1. Primary Racial Upgrades
	var prim_header := Label.new()
	prim_header.text = "— MEJORAS RACIALES PRIMARIAS (ARMAMENTO, BLINDAJE, VITALIDAD) —"
	prim_header.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
	list.add_child(prim_header)

	for up_id in ["weapon_damage", "armor_plating", "bio_vitality", "plasma_reactor", "attack_speed"]:
		_add_racial_upgrade_row(list, up_id)

	list.add_child(HSeparator.new())

	# 2. Unit-Specific Upgrades (Task 4.9)
	var unit_header := Label.new()
	unit_header.text = "— MEJORAS ESPECÍFICAS DE UNIDAD (TAREA 4.9) —"
	unit_header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	list.add_child(unit_header)

	for up_id in ["unit_gauss", "unit_concussion", "unit_cloak", "unit_void_blade", "unit_storm", "unit_nano"]:
		_add_racial_upgrade_row(list, up_id)


func _add_racial_upgrade_row(container: VBoxContainer, up_id: String) -> void:
	var def: Dictionary = RACIAL_UPGRADE_DEFS[up_id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	container.add_child(row)

	var title_lbl := Label.new()
	title_lbl.text = def["title"]
	title_lbl.custom_minimum_size = Vector2(190, 0)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	row.add_child(title_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Nv. 0 / %d" % def["max_lvl"]
	lvl_lbl.custom_minimum_size = Vector2(80, 0)
	racial_labels[up_id] = lvl_lbl
	row.add_child(lvl_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = def["desc"]
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	row.add_child(desc_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "+1 (%d 💎)" % def["base_cost"]
	buy_btn.custom_minimum_size = Vector2(130, 28)
	racial_buttons[up_id] = buy_btn
	buy_btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var is_shift: bool = event.shift_pressed
			var is_ctrl: bool = event.ctrl_pressed
			_on_racial_upgrade_clicked(up_id, is_shift, is_ctrl)
	)
	row.add_child(buy_btn)


func _get_upgrade_cost(def: Dictionary, level: int) -> int:
	var base_cost: int = def.get("base_cost", 100)
	var growth: float = def.get("growth", 1.15)
	return int(round(float(base_cost) * pow(growth, float(level))))


func _on_racial_upgrade_clicked(upgrade_id: String, is_shift: bool, is_ctrl: bool) -> void:
	if not economy_manager or not stats_comp:
		return

	var def: Dictionary = RACIAL_UPGRADE_DEFS.get(upgrade_id, {})
	var max_lvl: int = def.get("max_lvl", 20)
	var cur_lvl: int = racial_levels.get(upgrade_id, 0)

	if cur_lvl >= max_lvl:
		return

	var available_minerals: int = economy_manager.current_minerals
	var levels_to_buy: int = 1
	if is_shift:
		levels_to_buy = max_lvl - cur_lvl
	elif is_ctrl:
		levels_to_buy = mini(5, max_lvl - cur_lvl)

	var total_spent: int = 0
	var actual_bought: int = 0
	var sim_lvl: int = cur_lvl
	var sim_min: int = available_minerals

	for i in range(levels_to_buy):
		var cost := _get_upgrade_cost(def, sim_lvl)
		if sim_min < cost or sim_lvl >= max_lvl:
			break
		sim_min -= cost
		total_spent += cost
		sim_lvl += 1
		actual_bought += 1

	if actual_bought > 0 and total_spent > 0:
		if economy_manager.spend_minerals(total_spent):
			racial_levels[upgrade_id] += actual_bought
			_apply_racial_upgrade_effects(upgrade_id, actual_bought)
			racial_upgrade_purchased.emit(upgrade_id, racial_levels[upgrade_id])
			_play_purchase_sfx(true)
			_refresh_all_tabs()
		else:
			_play_purchase_sfx(false)
	else:
		_play_purchase_sfx(false)


func _apply_racial_upgrade_effects(upgrade_id: String, count: int) -> void:
	if not stats_comp:
		return
	match upgrade_id:
		"weapon_damage":
			stats_comp.damage_upgrade_mult += 0.05 * float(count)
			stats_comp.base_damage += 3.0 * float(count)
		"armor_plating":
			stats_comp.armor_upgrade_flat += 1.0 * float(count)
		"bio_vitality":
			stats_comp.hp_upgrade_mult += 0.05 * float(count)
			stats_comp.base_max_hp += 50.0 * float(count)
		"plasma_reactor":
			stats_comp.base_max_energy += 25.0 * float(count)
			stats_comp.base_energy_regen += 0.25 * float(count)
		"attack_speed":
			stats_comp.attack_speed_upgrade_mult += 0.04 * float(count)
		"unit_gauss":
			stats_comp.attack_speed_upgrade_mult += 0.15 * float(count)
			stats_comp.base_damage += 2.0 * float(count)
		"unit_concussion":
			stats_comp.base_max_hp += 25.0 * float(count)
			if target_unit:
				target_unit.set_meta("concussive_slow", true)
				if "concussive_slow" in target_unit:
					target_unit.concussive_slow = true
		"unit_cloak":
			stats_comp.base_max_energy += 30.0 * float(count)
			if target_unit:
				if "attack_range" in target_unit:
					target_unit.attack_range += 1.5 * float(count)
				if "hero_data" in target_unit and target_unit.hero_data and "attack_range" in target_unit.hero_data:
					target_unit.hero_data.attack_range += 1.5 * float(count)
		"unit_void_blade":
			stats_comp.base_damage += 8.0 * float(count)
			stats_comp.base_move_speed += 0.5 * float(count)
		"unit_storm":
			stats_comp.base_shield += 15.0 * float(count)
			stats_comp.ability_power_upgrade_bonus += 0.20 * float(count)
			if target_unit and "hero_data" in target_unit and target_unit.hero_data:
				target_unit.hero_data.max_shield += 15.0 * float(count)
				target_unit.hero_data.current_shield = target_unit.hero_data.max_shield
		"unit_nano":
			stats_comp.base_max_hp += 150.0 * float(count)
			if target_unit:
				var cur_b: float = target_unit.get_meta("healing_power_bonus", 0.0)
				target_unit.set_meta("healing_power_bonus", cur_b + 0.25 * float(count))
				if "healing_power" in target_unit:
					target_unit.healing_power += 0.25 * float(count)
	stats_comp.mark_dirty()


func _build_recruitment_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Reclutamiento y Élite"
	tab.add_theme_constant_override("separation", 12)
	tab_container.add_child(tab)

	# 1. Section: Veteranía Élite (Tarea 6.1)
	var elite_box := PanelContainer.new()
	var elite_style := StyleBoxFlat.new()
	elite_style.bg_color = Color(0.08, 0.10, 0.16, 0.95)
	elite_style.border_color = Color(1.0, 0.75, 0.2, 0.9)
	elite_style.set_border_width_all(1)
	elite_style.set_corner_radius_all(4)
	elite_style.content_margin_left = 12.0
	elite_style.content_margin_right = 12.0
	elite_style.content_margin_top = 8.0
	elite_style.content_margin_bottom = 8.0
	elite_box.add_theme_stylebox_override("panel", elite_style)
	tab.add_child(elite_box)

	var elite_vbox := VBoxContainer.new()
	elite_vbox.add_theme_constant_override("separation", 6)
	elite_box.add_child(elite_vbox)

	var elite_title := Label.new()
	elite_title.text = "★ SISTEMA DE VETERANÍA ÉLITE (TAREA 6.1) ★"
	elite_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	elite_vbox.add_child(elite_title)

	elite_info_lbl = Label.new()
	elite_info_lbl.text = "Unidad seleccionada: Normal. Puedes ascenderla a Élite para acumular hasta +125 daño y x1.67 vel. ataque."
	elite_info_lbl.add_theme_font_size_override("font_size", 12)
	elite_info_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	elite_vbox.add_child(elite_info_lbl)

	elite_upgrade_btn = Button.new()
	elite_upgrade_btn.text = "★ ASCENDER A VETERANÍA ÉLITE (500 💎)"
	elite_upgrade_btn.custom_minimum_size = Vector2(280, 32)
	elite_upgrade_btn.pressed.connect(_on_buy_veterancy_pressed)
	elite_vbox.add_child(elite_upgrade_btn)

	# 2. Section: Reclutamiento de Tropas y Apoyo (Tareas 6.3 - 6.7)
	var recruit_header := HBoxContainer.new()
	tab.add_child(recruit_header)

	var rec_title := Label.new()
	rec_title.text = "— RECLUTAMIENTO DE TROPAS Y UNIDADES DE VISIÓN/APOYO —"
	rec_title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	recruit_header.add_child(rec_title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_header.add_child(sp)

	supply_lbl = Label.new()
	supply_lbl.text = "Suministro: 1 / 80"
	supply_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	recruit_header.add_child(supply_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	_add_recruit_row(list, "marine", "Marine Terran", "Infantería ligera con rifle Gauss", 50, 1)
	_add_recruit_row(list, "zealot", "Zealot Protoss", "Combatiente cuerpo a cuerpo con escudos de plasma", 100, 2)
	_add_recruit_row(list, "zergling", "Zergling Enjambre", "Criatura rápida de flanqueo", 25, 1)
	_add_recruit_row(list, "observer", "Observer Protoss", "Unidad voladora de detección y visión táctica", 150, 1)
	_add_recruit_row(list, "blimp", "Medivac / Tactical Blimp", "Nave táctica de visión y apoyo aéreo", 150, 1)


func _add_recruit_row(container: VBoxContainer, unit_id: String, unit_name: String, desc: String, cost: int, supply: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	container.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = "%s (%d Sup)" % [unit_name, supply]
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	row.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	row.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "Reclutar (%d 💎)" % cost
	btn.custom_minimum_size = Vector2(130, 28)
	recruit_buttons[unit_id] = btn
	btn.pressed.connect(func(): _on_recruit_unit_pressed(unit_id))
	row.add_child(btn)


func _on_buy_veterancy_pressed() -> void:
	if not target_unit:
		return
	if UnitRecruitmentManager.buy_veterancy(target_unit, economy_manager):
		if target_unit.has_node("EliteComponent"):
			elite_comp = target_unit.get_node("EliteComponent") as EliteComponent
		_refresh_all_tabs()


func _on_recruit_unit_pressed(unit_id: String) -> void:
	if not economy_manager:
		return
	var cur_sup: int = _get_current_supply()
	var max_sup: int = _get_max_supply()
	var spawn_pos := Vector3(-20.0, 0.0, 20.0)
	if target_unit and target_unit is Node3D:
		spawn_pos = target_unit.global_position + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))

	var parent_scene: Node = get_tree().current_scene if get_tree() else null
	var u := UnitRecruitmentManager.recruit_unit(
		unit_id,
		spawn_pos,
		parent_scene,
		economy_manager,
		cur_sup,
		max_sup,
		buff_comp != null and buff_comp.is_ace_active
	)
	if u:
		unit_recruited.emit(u, UnitRecruitmentManager.RECRUIT_CATALOG[unit_id]["cost"])
		_refresh_all_tabs()
		if is_inside_tree() and get_tree():
			var hud = get_tree().root.find_child("SC2HUDRoot", true, false)
			if hud and hud.has_method("update_supply"):
				hud.update_supply(_get_current_supply(), _get_max_supply())


func _get_current_supply() -> int:
	if not is_inside_tree():
		return 1
	var allies := get_tree().get_nodes_in_group("allies")
	return maxi(1, allies.size())


func _get_max_supply() -> int:
	var sess = Engine.get_singleton("GameSession") if Engine.has_singleton("GameSession") else null
	if not sess and is_inside_tree() and get_tree() and get_tree().root.has_node("GameSession"):
		sess = get_tree().root.get_node("GameSession")
	if sess and sess.has_method("get_max_supply"):
		return sess.get_max_supply()
	return 80


func _refresh_all_tabs() -> void:
	if economy_manager:
		minerals_lbl.text = "💎 %d" % economy_manager.current_minerals
	
	if target_name_lbl:
		var t_name: String = target_unit.name if target_unit else "JIM RAYNOR"
		if target_unit and "hero_data" in target_unit and target_unit.hero_data:
			t_name = target_unit.hero_data.hero_name
		target_name_lbl.text = "CONSOLA DEL JUGADOR — [%s]" % t_name.to_upper()

	if stats_comp:
		for attr in ["strength", "dexterity", "intelligence", "endurance"]:
			var pts := stats_comp.get_attribute_value(attr)
			var cost := stats_comp.get_next_attribute_cost(attr)
			if attr_labels.has(attr):
				attr_labels[attr].text = "%d pts" % pts
			if attr_buttons.has(attr):
				attr_buttons[attr].text = "+1 (%d 💎)" % cost
				attr_buttons[attr].disabled = (economy_manager != null and economy_manager.current_minerals < cost)
		
		var na_lbl := root_panel.find_child("NeutronArmorLabel", true, false) as Label
		var na_btn := root_panel.find_child("NeutronArmorBtn", true, false) as Button
		if na_lbl and na_btn:
			na_lbl.text = "Neutron Armor (Nivel %d): +%.1f Mitigación plana contra todo daño" % [
				stats_comp.neutron_armor_level,
				stats_comp.get_neutron_armor_mitigation()
			]
			var na_cost := stats_comp.get_next_neutron_armor_cost()
			na_btn.text = "Mejorar (%d 💎)" % na_cost
			na_btn.disabled = (economy_manager != null and economy_manager.current_minerals < na_cost)

	# Refresh Racial Upgrades tab
	for up_id in RACIAL_UPGRADE_DEFS.keys():
		var def: Dictionary = RACIAL_UPGRADE_DEFS[up_id]
		var cur_lvl: int = racial_levels.get(up_id, 0)
		var max_lvl: int = def.get("max_lvl", 20)
		var cost := _get_upgrade_cost(def, cur_lvl)
		if racial_labels.has(up_id):
			racial_labels[up_id].text = "Nv. %d / %d" % [cur_lvl, max_lvl]
		if racial_buttons.has(up_id):
			if cur_lvl >= max_lvl:
				racial_buttons[up_id].text = "MÁXIMO"
				racial_buttons[up_id].disabled = true
			else:
				racial_buttons[up_id].text = "+1 (%d 💎)" % cost
				racial_buttons[up_id].disabled = (economy_manager != null and economy_manager.current_minerals < cost)

	# Refresh Elite Veterancy Section
	if elite_info_lbl:
		var is_el: bool = elite_comp.is_elite if elite_comp else false
		var st: int = elite_comp.elite_stacks if elite_comp else 0
		var bonus_d: float = elite_comp.get_bonus_damage() if elite_comp else 0.0
		var spd: float = elite_comp.get_attack_speed_multiplier() if elite_comp else 1.0
		if is_el:
			elite_info_lbl.text = "★ UNIDAD ÉLITE ACTIVA ★ Bajas: %d / 125 | Daño extra: +%.0f | Vel. Ataque: x%.2f" % [st, bonus_d, spd]
			if elite_upgrade_btn:
				elite_upgrade_btn.disabled = true
				elite_upgrade_btn.text = "★ YA ES VETERANA ÉLITE ★"
		else:
			elite_info_lbl.text = "Unidad: Normal. Puedes ascenderla a Élite para acumular hasta +125 daño y x1.67 vel. ataque por bajas."
			if elite_upgrade_btn:
				var vet_cost: int = UnitRecruitmentManager.VETERANCY_COST
				elite_upgrade_btn.disabled = (economy_manager == null or economy_manager.current_minerals < vet_cost)
				elite_upgrade_btn.text = "★ ASCENDER A VETERANÍA ÉLITE (%d 💎)" % vet_cost

	# Refresh Supply & Recruitment
	var cur_sup: int = _get_current_supply()
	var max_sup: int = _get_max_supply()
	if supply_lbl:
		supply_lbl.text = "Suministro: %d / %d" % [cur_sup, max_sup]
	for u_id in recruit_buttons.keys():
		var check: Dictionary = UnitRecruitmentManager.can_recruit(u_id, economy_manager.current_minerals if economy_manager else 0, cur_sup, max_sup)
		recruit_buttons[u_id].disabled = not check.get("can_recruit", false)

	# If allow_buff_purchase is false (e.g. Hardcore mode), disable buff tab / purchases
	if tab_container and tab_container.get_tab_count() > 1:
		tab_container.set_tab_disabled(1, not allow_buff_purchase)


func _play_purchase_sfx(success: bool) -> void:
	var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
	if SFXM and SFXM.instance != null:
		if success:
			SFXM.instance.play_sfx_2d(&"upgrade_complete")
		else:
			SFXM.instance.play_voice_alert(&"insufficient_minerals")


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
			_play_purchase_sfx(true)
		else:
			_play_purchase_sfx(false)
	else:
		# Single point purchase
		var cost := stats_comp.get_next_attribute_cost(attr_id)
		if available_minerals >= cost:
			if economy_manager.spend_minerals(cost):
				stats_comp.invest_attribute(attr_id, 1)
				attribute_purchased.emit(attr_id, 1)
				_play_purchase_sfx(true)
			else:
				_play_purchase_sfx(false)
		else:
			_play_purchase_sfx(false)
	
	_refresh_all_tabs()


func _on_neutron_armor_pressed() -> void:
	if not stats_comp or not economy_manager:
		return
	var cost := stats_comp.get_next_neutron_armor_cost()
	if economy_manager.current_minerals >= cost:
		if economy_manager.spend_minerals(cost):
			stats_comp.upgrade_neutron_armor()
			_play_purchase_sfx(true)
			_refresh_all_tabs()
		else:
			_play_purchase_sfx(false)
	else:
		_play_purchase_sfx(false)


func _on_buy_buff_pressed(tier: int, buff_id: String, buff_name: String, cost: int) -> void:
	if not allow_buff_purchase or not buff_comp or not economy_manager:
		return
	if economy_manager.current_minerals < cost:
		_play_purchase_sfx(false)
		return
	
	if economy_manager.spend_minerals(cost):
		var res := buff_comp.equip_tier_buff(tier, buff_id, buff_name, cost)
		var refund: int = res.get("refund", 0)
		if refund > 0:
			economy_manager.add_minerals(refund)
		buff_purchased.emit(tier, buff_id)
		_play_purchase_sfx(true)
		_refresh_all_tabs()
	else:
		_play_purchase_sfx(false)


func _on_buy_supreme_pressed(buff_id: String, cost: int) -> void:
	if not allow_buff_purchase or not buff_comp or not economy_manager:
		return
	
	var success: bool = false
	if buff_id == "ace":
		if economy_manager.current_minerals >= cost and economy_manager.spend_minerals(cost):
			buff_comp.unlock_ace()
			success = true
	elif buff_id == "demiurge":
		if economy_manager.current_minerals >= cost and economy_manager.spend_minerals(cost):
			buff_comp.unlock_demiurge()
			success = true
	elif buff_id == "maxima_experiencia":
		var hero_lvl := 1
		if target_unit:
			if "experience_component" in target_unit and target_unit.experience_component:
				hero_lvl = target_unit.experience_component.current_level
			elif "hero_data" in target_unit and target_unit.hero_data and "xp_level" in target_unit.hero_data:
				hero_lvl = target_unit.hero_data.xp_level
			elif "level" in target_unit:
				hero_lvl = target_unit.level
		var res := buff_comp.purchase_maxima_experiencia(hero_lvl, economy_manager.current_minerals)
		if res.get("success", false):
			var actual_cost: int = res.get("cost", cost)
			economy_manager.spend_minerals(actual_cost)
			if target_unit:
				if "experience_component" in target_unit and target_unit.experience_component:
					target_unit.experience_component.current_level = 100
				if "hero_data" in target_unit and target_unit.hero_data and "xp_level" in target_unit.hero_data:
					target_unit.hero_data.xp_level = 100
				if "level" in target_unit:
					target_unit.level = 100
			var gained: int = maxi(0, 100 - hero_lvl)
			if stats_comp:
				stats_comp.strength += gained * 2
				stats_comp.dexterity += gained * 2
				stats_comp.intelligence += gained * 2
				stats_comp.endurance += gained * 2
				stats_comp.mark_dirty()
			AchievementSystem.unlock_achievement(&"ach_hero_ascendance")
			success = true

	_play_purchase_sfx(success)
	_refresh_all_tabs()
