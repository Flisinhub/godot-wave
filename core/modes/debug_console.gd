class_name DebugConsole
extends RefCounted

## DebugConsole - SFE5 In-Game Developer Console (Ctrl+Alt+C) (Task 11.8).
## Provides testing commands for mineral injection, enemy clearing, phase skipping, and unit spawning.

signal debug_message_logged(msg: String, is_error: bool)
signal hero_teleported(target_pos: Vector3)

var is_god_mode: bool = false
var economy_manager: Object = null
var story_phase_manager: Object = null
var active_hero: Object = null


func _init(p_econ: Object = null, p_story: Object = null, p_hero: Object = null) -> void:
	economy_manager = p_econ
	story_phase_manager = p_story
	active_hero = p_hero


## Parses and executes a single CLI string command (e.g. "give 50000", "kill", "god").
func execute_command_string(raw: String) -> String:
	var clean: String = raw.strip_edges()
	if clean.is_empty():
		return ""

	var parts: PackedStringArray = clean.split(" ", false)
	var cmd: String = parts[0].to_lower()
	var args: PackedStringArray = parts.slice(1)

	match cmd:
		"give", "minerals":
			var amount: int = args[0].to_int() if args.size() > 0 else 50000
			return give_minerals(amount)
		"kill", "clear":
			return kill_all_enemies()
		"god":
			is_god_mode = not is_god_mode
			return "Modo Invulnerabilidad: %s" % ("ACTIVADO" if is_god_mode else "DESACTIVADO")
		"phase":
			var p: int = args[0].to_int() if args.size() > 0 else 1
			return advance_story_phase(p)
		"teleport", "tp":
			var x: float = args[0].to_float() if args.size() > 0 else 0.0
			var z: float = args[1].to_float() if args.size() > 1 else 0.0
			return teleport_hero(Vector3(x, 0.0, z))
		"help":
			return "Comandos disponibles: give <N>, kill, god, phase <1-3>, tp <x> <z>"
		_:
			return "Comando desconocido: '%s'. Escribe 'help' para ver la lista." % cmd


func give_minerals(amount: int) -> String:
	if economy_manager != null and economy_manager.has_method("add_minerals"):
		economy_manager.add_minerals(amount, "Debug Console Injection")
		return "Añadidos %d minerales al monedero." % amount
	return "No se pudo inyectar mineral: EconomyManager no disponible."


func kill_all_enemies() -> String:
	var count: int = 0
	if Engine.has_singleton("SceneTree"):
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			var enemies: Array = tree.get_nodes_in_group("enemies")
			for e in enemies:
				if is_instance_valid(e) and e.has_method("take_damage"):
					e.take_damage(999999.0, true)
					count += 1
	return "Eliminados %d enemigos del mapa." % count


func advance_story_phase(phase_index: int) -> String:
	if story_phase_manager != null and story_phase_manager.has_method("advance_to_phase"):
		story_phase_manager.advance_to_phase(phase_index)
		return "Fase de historia avanzada a %d." % phase_index
	return "StoryPhaseManager no disponible."


func teleport_hero(pos: Vector3) -> String:
	if active_hero != null and is_instance_valid(active_hero) and active_hero is Node3D:
		if active_hero.is_inside_tree():
			active_hero.global_position = pos
		else:
			active_hero.position = pos
		hero_teleported.emit(pos)
		return "Héroe teletransportado a %s." % str(pos)
	return "Héroe no disponible para teletransporte."
