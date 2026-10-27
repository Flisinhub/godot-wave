class_name ArmoryModal
extends CanvasLayer

## ArmoryModal - StarCraft II Style Interactive Tactical Armory Console.
## Allows the Hero to invest mineral bounties into Ballistics Arsenal (Tiers 1–5),
## Armor & Survival (Tiers 1–5), and Automated Perimeter Turret Deployments.
## Features translucent beveled military UI, real-time telemetry, and [ESC] / [E] dismissal.

signal modal_opened
signal modal_closed
signal upgrade_purchased(category: StringName, new_tier: int, cost: int)
signal turret_deployed(turret: Node3D, remaining_cap: int)

const BALLISTICS_COSTS: Array[int] = [100, 250, 500, 900, 1500]
const ARMOR_COSTS: Array[int] = [100, 225, 450, 800, 1400]
const TURRET_COST: int = 125
const MAX_UPGRADE_TIER: int = 5
const MAX_TURRETS: int = 6

const TURRET_DEFENSIVE_SLOTS: Array[Vector3] = [
	Vector3(-14.0, 0.0, 14.0),
	Vector3(-16.0, 0.0, 12.0),
	Vector3(-12.0, 0.0, 16.0),
	Vector3(-15.0, 0.0, 15.0),
	Vector3(-10.0, 0.0, 18.0),
	Vector3(-18.0, 0.0, 12.0)
]

var linked_terminal: Node = null

# UI Root Nodes
var root_control: Control = null
var backdrop_rect: ColorRect = null
var modal_panel: PanelContainer = null
var header_title: Label = null
var header_minerals: Label = null
var close_icon_btn: Button = null

# Ballistics Row Elements
var ballistics_tier_label: Label = null
var ballistics_desc_label: Label = null
var ballistics_cost_label: Label = null
var ballistics_buy_btn: Button = null

# Armor Row Elements
var armor_tier_label: Label = null
var armor_desc_label: Label = null
var armor_cost_label: Label = null
var armor_buy_btn: Button = null

# Turrets Row Elements
var turret_count_label: Label = null
var turret_desc_label: Label = null
var turret_cost_label: Label = null
var turret_deploy_btn: Button = null

# Footer Elements
var footer_hint_label: Label = null
var dismiss_btn: Button = null


func _init() -> void:
	layer = 95
	_build_modal_layout()


func _ready() -> void:
	_build_modal_layout()
	refresh_ui()


func _process(_delta: float) -> void:
	if visible:
		refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_modal()
			var vp: Viewport = get_viewport()
			if vp != null:
				vp.set_input_as_handled()


func open_modal(terminal: Node = null) -> void:
	linked_terminal = terminal
	visible = true
	refresh_ui()
	modal_opened.emit()


func close_modal() -> void:
	if not visible:
		return
	visible = false
	if linked_terminal != null and is_instance_valid(linked_terminal):
		if linked_terminal.has_method("close_terminal") and linked_terminal.get("is_terminal_open") == true:
			linked_terminal.close_terminal()
	linked_terminal = null
	modal_closed.emit()


func _get_upgrade_manager() -> Object:
	var MgrScript: GDScript = load("res://core/upgrades/armory_upgrade_manager.gd") as GDScript
	if MgrScript and MgrScript.instance != null:
		return MgrScript.instance
	if is_inside_tree() and get_tree().current_scene:
		var node: Node = get_tree().current_scene.get_node_or_null("ArmoryUpgradeManager")
		if node != null:
			return node
		if MgrScript != null:
			var new_mgr: Node = MgrScript.new() as Node
			new_mgr.name = "ArmoryUpgradeManager"
			get_tree().current_scene.add_child(new_mgr)
			return new_mgr
	return null


func _get_economy() -> Object:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("_get_economy"):
		var econ: Object = mgr._get_economy()
		if econ != null:
			return econ
	var SFEEconomyManagerScript: GDScript = load("res://core/economy/sfe_economy_manager.gd") as GDScript
	if SFEEconomyManagerScript and SFEEconomyManagerScript.instance != null:
		return SFEEconomyManagerScript.instance
	if is_inside_tree() and get_tree().current_scene:
		return get_tree().current_scene.get_node_or_null("EconomyManager")
	return null


func get_current_minerals() -> int:
	var econ: Object = _get_economy()
	if econ != null:
		if "current_minerals" in econ:
			return int(econ.current_minerals)
		elif econ.has_method("get_minerals"):
			return int(econ.get_minerals())
	return 0


func can_purchase_ballistics() -> bool:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("can_purchase_ballistics"):
		return bool(mgr.can_purchase_ballistics())
	return false


func purchase_ballistics() -> bool:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("purchase_ballistics"):
		var old_tier: int = int(mgr.get("ballistics_tier"))
		if mgr.purchase_ballistics():
			var new_tier: int = int(mgr.get("ballistics_tier"))
			var cost: int = BALLISTICS_COSTS[old_tier] if old_tier < BALLISTICS_COSTS.size() else 0
			_apply_upgrades_to_scene_heroes(mgr)
			upgrade_purchased.emit(&"ballistics", new_tier, cost)
			refresh_ui()
			return true
	return false


func can_purchase_armor() -> bool:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("can_purchase_armor"):
		return bool(mgr.can_purchase_armor())
	return false


func purchase_armor() -> bool:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("purchase_armor"):
		var old_tier: int = int(mgr.get("armor_tier"))
		if mgr.purchase_armor():
			var new_tier: int = int(mgr.get("armor_tier"))
			var cost: int = ARMOR_COSTS[old_tier] if old_tier < ARMOR_COSTS.size() else 0
			_apply_upgrades_to_scene_heroes(mgr)
			upgrade_purchased.emit(&"armor", new_tier, cost)
			refresh_ui()
			return true
	return false


func can_deploy_turret() -> bool:
	var mgr: Object = _get_upgrade_manager()
	if mgr != null and mgr.has_method("can_deploy_turret"):
		return bool(mgr.can_deploy_turret())
	return false


func deploy_turret(world_position: Vector3 = Vector3.ZERO) -> Node3D:
	var mgr: Object = _get_upgrade_manager()
	if mgr == null or not mgr.has_method("deploy_turret"):
		return null
	if not bool(mgr.can_deploy_turret()):
		return null

	var target_pos: Vector3 = world_position
	if target_pos == Vector3.ZERO or (mgr.has_method("is_valid_turret_position") and not bool(mgr.is_valid_turret_position(target_pos))):
		target_pos = _find_best_turret_placement(mgr)

	var turret: Node3D = mgr.deploy_turret(target_pos) as Node3D
	if turret != null:
		if turret.get_parent() == null:
			var p: Node = get_parent()
			if p != null:
				p.add_child(turret)
		var dep_count: int = mgr.deployed_turrets.size() if "deployed_turrets" in mgr else 1
		turret_deployed.emit(turret, MAX_TURRETS - dep_count)
		refresh_ui()
	return turret


func _apply_upgrades_to_scene_heroes(mgr: Object) -> void:
	var heroes: Array = []
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null:
			heroes = tree.get_nodes_in_group("heroes")
	var p: Node = get_parent()
	while p != null:
		for ch in p.get_children():
			if (ch.is_in_group("heroes") or ch.is_in_group("allies")) and not heroes.has(ch):
				heroes.append(ch)
		p = p.get_parent()
	for hero in heroes:
		if is_instance_valid(hero) and hero.has_method("apply_armory_upgrades"):
			hero.apply_armory_upgrades(mgr)


func _find_best_turret_placement(mgr: Object) -> Vector3:
	var deployed: Array = mgr.get("deployed_turrets") if "deployed_turrets" in mgr else []
	for slot: Vector3 in TURRET_DEFENSIVE_SLOTS:
		var occupied: bool = false
		for t: Variant in deployed:
			if t is Node3D and is_instance_valid(t as Node3D):
				if (t as Node3D).global_position.distance_to(slot) < 2.0:
					occupied = true
					break
		if not occupied:
			if mgr.has_method("is_valid_turret_position"):
				if bool(mgr.is_valid_turret_position(slot)):
					return slot
			else:
				return slot

	if mgr.has_method("_get_command_center_position"):
		var cc_pos: Vector3 = mgr._get_command_center_position()
		for angle_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
			var rad: float = deg_to_rad(float(angle_deg))
			var candidate: Vector3 = cc_pos + Vector3(cos(rad) * 12.0, 0.0, sin(rad) * 12.0)
			if mgr.has_method("is_valid_turret_position") and bool(mgr.is_valid_turret_position(candidate)):
				return candidate

	return TURRET_DEFENSIVE_SLOTS[0]


func refresh_ui() -> void:
	var mgr: Object = _get_upgrade_manager()
	var minerals: int = get_current_minerals()

	# 1. Update Minerals telemetry
	if header_minerals != null:
		header_minerals.text = "💎 %d MINERALS" % minerals

	# 2. Update Ballistics Arsenal
	var b_tier: int = int(mgr.get("ballistics_tier")) if mgr != null else 0
	if ballistics_tier_label != null:
		var pips: String = _format_pips(b_tier, MAX_UPGRADE_TIER)
		ballistics_tier_label.text = "BALLISTICS ARSENAL  %s  (TIER %d/%d)" % [pips, b_tier, MAX_UPGRADE_TIER]
	if ballistics_desc_label != null:
		var dmg_pct: int = int(round(15.0 * b_tier))
		var spd_pct: int = int(round(8.0 * b_tier))
		var rng_m: float = 0.6 * b_tier
		ballistics_desc_label.text = "+15%% Daño, +8%% Vel. Ataque, +0.6m Rango por nivel\nActual: +%d%% Daño | +%d%% Vel. Ataque | +%.1fm Rango" % [dmg_pct, spd_pct, rng_m]
	if ballistics_cost_label != null and ballistics_buy_btn != null:
		if b_tier >= MAX_UPGRADE_TIER:
			ballistics_cost_label.text = "ESTADO: NIVEL MÁXIMO (TIER 5)"
			ballistics_buy_btn.text = "COMPLETO"
			ballistics_buy_btn.disabled = true
		else:
			var cost: int = BALLISTICS_COSTS[b_tier]
			ballistics_cost_label.text = "Coste siguiente nivel: %d Minerales" % cost
			ballistics_buy_btn.text = "MEJORAR ( %d 💎 )" % cost
			var can_afford: bool = can_purchase_ballistics()
			ballistics_buy_btn.disabled = not can_afford

	# 3. Update Armor & Survival
	var a_tier: int = int(mgr.get("armor_tier")) if mgr != null else 0
	if armor_tier_label != null:
		var pips: String = _format_pips(a_tier, MAX_UPGRADE_TIER)
		armor_tier_label.text = "ARMOR & SURVIVAL  %s  (TIER %d/%d)" % [pips, a_tier, MAX_UPGRADE_TIER]
	if armor_desc_label != null:
		var flat_arm: int = 2 * a_tier
		var hp_reg: float = 2.5 * a_tier
		var mitig_pct: int = int(round(4.0 * a_tier))
		armor_desc_label.text = "+2 Armadura Plana, +2.5 HP/s Regen, +4%% Mitigación Estructural\nActual: +%d Armadura | +%.1f HP/s | +%d%% Mitigación Base" % [flat_arm, hp_reg, mitig_pct]
	if armor_cost_label != null and armor_buy_btn != null:
		if a_tier >= MAX_UPGRADE_TIER:
			armor_cost_label.text = "ESTADO: NIVEL MÁXIMO (TIER 5)"
			armor_buy_btn.text = "COMPLETO"
			armor_buy_btn.disabled = true
		else:
			var cost: int = ARMOR_COSTS[a_tier]
			armor_cost_label.text = "Coste siguiente nivel: %d Minerales" % cost
			armor_buy_btn.text = "MEJORAR ( %d 💎 )" % cost
			var can_afford: bool = can_purchase_armor()
			armor_buy_btn.disabled = not can_afford

	# 4. Update Automated Perimeter Turrets
	var active_turrets: int = 0
	if mgr != null and "deployed_turrets" in mgr:
		if mgr.has_method("_cleanup_turrets"):
			mgr._cleanup_turrets()
		active_turrets = (mgr.get("deployed_turrets") as Array).size()
	if turret_count_label != null:
		turret_count_label.text = "AUTOMATED PERIMETER TURRETS  [ %d / %d DESPLEGADAS ]" % [active_turrets, MAX_TURRETS]
	if turret_desc_label != null:
		turret_desc_label.text = "Torreta doble Gatling: 350 HP, 2 Armadura, 14 Daño Físico, 10.5m Rango, 0.35s Cadencia\nDespliegue perimetral automático defensivo contra brechas del enjambre."
	if turret_cost_label != null and turret_deploy_btn != null:
		if active_turrets >= MAX_TURRETS:
			turret_cost_label.text = "ESTADO: CAPACIDAD MÁXIMA ALCANZADA (6/6)"
			turret_deploy_btn.text = "LÍMITE ALCANZADO"
			turret_deploy_btn.disabled = true
		else:
			turret_cost_label.text = "Coste por torreta: %d Minerales" % TURRET_COST
			turret_deploy_btn.text = "DESPLEGAR ( %d 💎 )" % TURRET_COST
			var can_afford: bool = can_deploy_turret()
			turret_deploy_btn.disabled = not can_afford


func _format_pips(current: int, total: int) -> String:
	var out: String = "["
	for i in range(total):
		if i < current:
			out += "■"
		else:
			out += "□"
	out += "]"
	return out


func _build_modal_layout() -> void:
	if root_control != null:
		return

	# Root full-screen container
	root_control = Control.new()
	root_control.name = "ArmoryControlRoot"
	root_control.anchor_left = 0.0
	root_control.anchor_top = 0.0
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Dimmed tactical backdrop
	backdrop_rect = ColorRect.new()
	backdrop_rect.name = "BackdropTint"
	backdrop_rect.anchor_left = 0.0
	backdrop_rect.anchor_top = 0.0
	backdrop_rect.anchor_right = 1.0
	backdrop_rect.anchor_bottom = 1.0
	backdrop_rect.color = Color(0.015, 0.025, 0.04, 0.82)
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop_rect.gui_input.connect(_on_backdrop_gui_input)
	root_control.add_child(backdrop_rect)

	# Main StarCraft II Beveled Dialog Box
	modal_panel = PanelContainer.new()
	modal_panel.name = "ArmoryModalPanel"
	modal_panel.anchor_left = 0.5
	modal_panel.anchor_top = 0.5
	modal_panel.anchor_right = 0.5
	modal_panel.anchor_bottom = 0.5
	modal_panel.offset_left = -390.0
	modal_panel.offset_top = -290.0
	modal_panel.offset_right = 390.0
	modal_panel.offset_bottom = 290.0
	modal_panel.custom_minimum_size = Vector2(780, 580)

	var panel_style := _create_beveled_style(
		Color(0.035, 0.055, 0.085, 0.96),
		Color(0.22, 0.52, 0.85, 0.88),
		3,
		6
	)
	modal_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(modal_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	modal_panel.add_child(main_vbox)

	# 1. Header Bar: Title, Mineral balance, Close [✕]
	var header_bar := HBoxContainer.new()
	header_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_vbox.add_child(header_bar)

	header_title = Label.new()
	header_title.text = "TERRAN ARMORY  //  UPGRADE MATRIX"
	header_title.add_theme_color_override("font_color", Color(0.35, 0.88, 1.0))
	header_title.add_theme_font_size_override("font_size", 16)
	header_bar.add_child(header_title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(header_spacer)

	header_minerals = Label.new()
	header_minerals.text = "💎 0 MINERALS"
	header_minerals.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))
	header_minerals.add_theme_font_size_override("font_size", 15)
	header_bar.add_child(header_minerals)

	close_icon_btn = Button.new()
	close_icon_btn.text = " ✕ "
	close_icon_btn.custom_minimum_size = Vector2(32, 28)
	close_icon_btn.focus_mode = Control.FOCUS_NONE
	_style_military_button(close_icon_btn, Color(0.2, 0.05, 0.05, 0.8), Color(0.85, 0.25, 0.25, 0.9))
	close_icon_btn.pressed.connect(close_modal)
	header_bar.add_child(close_icon_btn)

	# Header Separator line
	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sep1)

	# 2. Content Container: 3 Upgrade Cards
	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(cards_vbox)

	# Card 1: Ballistics Arsenal
	_build_ballistics_card(cards_vbox)

	# Card 2: Armor & Survival
	_build_armor_card(cards_vbox)

	# Card 3: Automated Turrets
	_build_turrets_card(cards_vbox)

	# Separator before footer
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sep2)

	# 3. Footer Bar: Hint telemetry & Dismiss button
	var footer_bar := HBoxContainer.new()
	footer_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_vbox.add_child(footer_bar)

	footer_hint_label = Label.new()
	footer_hint_label.text = "Presiona [ESC] o [E] para salir de la terminal"
	footer_hint_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.8))
	footer_hint_label.add_theme_font_size_override("font_size", 12)
	footer_bar.add_child(footer_hint_label)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_bar.add_child(footer_spacer)

	dismiss_btn = Button.new()
	dismiss_btn.text = "CERRAR TERMINAL (ESC)"
	dismiss_btn.custom_minimum_size = Vector2(180, 34)
	dismiss_btn.focus_mode = Control.FOCUS_NONE
	_style_military_button(dismiss_btn, Color(0.06, 0.10, 0.16, 0.95), Color(0.3, 0.6, 0.9, 0.85))
	dismiss_btn.pressed.connect(close_modal)
	footer_bar.add_child(dismiss_btn)


func _build_ballistics_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _create_card_style())
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	ballistics_tier_label = Label.new()
	ballistics_tier_label.text = "BALLISTICS ARSENAL  [□□□□□]  (TIER 0/5)"
	ballistics_tier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	ballistics_tier_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(ballistics_tier_label)

	ballistics_desc_label = Label.new()
	ballistics_desc_label.text = "+15% Daño, +8% Vel. Ataque, +0.6m Rango por nivel"
	ballistics_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	ballistics_desc_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(ballistics_desc_label)

	ballistics_cost_label = Label.new()
	ballistics_cost_label.text = "Coste siguiente nivel: 100 Minerales"
	ballistics_cost_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	ballistics_cost_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(ballistics_cost_label)

	ballistics_buy_btn = Button.new()
	ballistics_buy_btn.text = "MEJORAR ( 100 💎 )"
	ballistics_buy_btn.custom_minimum_size = Vector2(190, 44)
	ballistics_buy_btn.focus_mode = Control.FOCUS_NONE
	_style_military_button(ballistics_buy_btn, Color(0.08, 0.14, 0.22, 0.95), Color(0.25, 0.65, 1.0, 0.9))
	ballistics_buy_btn.pressed.connect(_on_buy_ballistics_pressed)
	hbox.add_child(ballistics_buy_btn)


func _build_armor_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _create_card_style())
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	armor_tier_label = Label.new()
	armor_tier_label.text = "ARMOR & SURVIVAL  [□□□□□]  (TIER 0/5)"
	armor_tier_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.65))
	armor_tier_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(armor_tier_label)

	armor_desc_label = Label.new()
	armor_desc_label.text = "+2 Armadura Plana, +2.5 HP/s Regen, +4% Mitigación Estructural"
	armor_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	armor_desc_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(armor_desc_label)

	armor_cost_label = Label.new()
	armor_cost_label.text = "Coste siguiente nivel: 100 Minerales"
	armor_cost_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	armor_cost_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(armor_cost_label)

	armor_buy_btn = Button.new()
	armor_buy_btn.text = "MEJORAR ( 100 💎 )"
	armor_buy_btn.custom_minimum_size = Vector2(190, 44)
	armor_buy_btn.focus_mode = Control.FOCUS_NONE
	_style_military_button(armor_buy_btn, Color(0.08, 0.16, 0.18, 0.95), Color(0.25, 0.85, 0.65, 0.9))
	armor_buy_btn.pressed.connect(_on_buy_armor_pressed)
	hbox.add_child(armor_buy_btn)


func _build_turrets_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _create_card_style())
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	turret_count_label = Label.new()
	turret_count_label.text = "AUTOMATED PERIMETER TURRETS  [ 0 / 6 DESPLEGADAS ]"
	turret_count_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
	turret_count_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(turret_count_label)

	turret_desc_label = Label.new()
	turret_desc_label.text = "Torreta doble Gatling: 350 HP, 2 Armadura, 14 Daño, 10.5m Rango (Máx 6)"
	turret_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	turret_desc_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(turret_desc_label)

	turret_cost_label = Label.new()
	turret_cost_label.text = "Coste por torreta: 125 Minerales"
	turret_cost_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	turret_cost_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(turret_cost_label)

	turret_deploy_btn = Button.new()
	turret_deploy_btn.text = "DESPLEGAR ( 125 💎 )"
	turret_deploy_btn.custom_minimum_size = Vector2(190, 44)
	turret_deploy_btn.focus_mode = Control.FOCUS_NONE
	_style_military_button(turret_deploy_btn, Color(0.18, 0.12, 0.08, 0.95), Color(1.0, 0.65, 0.25, 0.9))
	turret_deploy_btn.pressed.connect(_on_deploy_turret_pressed)
	hbox.add_child(turret_deploy_btn)


func _on_buy_ballistics_pressed() -> void:
	purchase_ballistics()


func _on_buy_armor_pressed() -> void:
	purchase_armor()


func _on_deploy_turret_pressed() -> void:
	deploy_turret()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicking outside the dialog dismisses the modal
		var modal_rect: Rect2 = modal_panel.get_global_rect() if modal_panel != null else Rect2()
		if not modal_rect.has_point(event.global_position):
			close_modal()


func _create_beveled_style(bg: Color, border: Color, border_w: int, corner_r: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w
	s.border_color = border
	s.corner_radius_top_left = corner_r
	s.corner_radius_top_right = corner_r
	s.corner_radius_bottom_left = corner_r
	s.corner_radius_bottom_right = corner_r
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	s.shadow_size = 12
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 16.0
	s.content_margin_bottom = 16.0
	return s


func _create_card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.025, 0.04, 0.065, 0.92)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.18, 0.38, 0.6, 0.7)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


func _style_military_button(btn: Button, bg: Color, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = border
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.18)
	hover.border_color = border.lightened(0.25)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.04, 0.05, 0.07, 0.8)
	disabled.border_color = Color(0.2, 0.25, 0.3, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.5, 0.6))
	btn.add_theme_font_size_override("font_size", 12)
