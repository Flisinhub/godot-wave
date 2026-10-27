class_name AchievementSystem
extends RefCounted

## AchievementSystem - SFE5 Meta Achievements Engine (Tasks 12.3, 12.4, 12.8, 12.9).
## Tracks declarative achievements, computes total achievement score,
## and checks unlocks for Torment difficulty (Brutal win) and Secret Heroes (>= 3000 pts).

const BankManager = preload("res://core/persistence/bank_manager.gd")

signal achievement_unlocked(id: StringName, title: String, points: int)

# Catalog of 30 initial canonical achievements (Task 12.4)
const ACHIEVEMENTS: Dictionary = {
	&"ach_first_blood": {"title": "Primera Sangre", "desc": "Gana tu primera partida de SFE5", "points": 50},
	&"ach_brutal_conqueror": {"title": "Conquistador Brutal", "desc": "Gana una partida en dificultad Brutal", "points": 250},
	&"ach_torment_conqueror": {"title": "Señor del Tormento", "desc": "Gana una partida en dificultad Torment", "points": 500},
	&"ach_impossible_legend": {"title": "Leyenda Imposible", "desc": "Supera la dificultad Imposible", "points": 1000},
	&"ach_c8_mastery": {"title": "Maestro del Octagrama", "desc": "Resuelve el puzzle de los 8 pedestales", "points": 100},
	&"ach_outhouse": {"title": "Llamada de la Naturaleza", "desc": "Descubre el refugio secreto Outhouse", "points": 50},
	&"ach_lucky_lizard": {"title": "Cazador de Fortunas", "desc": "Atrapa al escurridizo Lucky Lizard", "points": 75},
	&"ach_odin_slayer": {"title": "Juicio Final", "desc": "Derrota al titán Odin", "points": 150},
	&"ach_gorgon_slayer": {"title": "Cielos Despejados", "desc": "Derrota al Gorgon en la antena SR-04", "points": 150},
	&"ach_diablo_slayer": {"title": "Terror Extinguido", "desc": "Derrota a Diablo en la Estación de Gas", "points": 150},
	&"ach_chaindog_slayer": {"title": "Desencadenado", "desc": "Derrota a Chaindog ante la estatua de Mengsk", "points": 150},
	&"ach_hybrid_behemoth_slayer": {"title": "Monstruosidad Anulada", "desc": "Derrota al Hybrid Behemoth", "points": 200},
	&"ach_hybrid_exp_slayer": {"title": "Experimento Fallido", "desc": "Derrota al Hybrid Experimented", "points": 150},
	&"ach_eclipse_slayer": {"title": "Amanecer Eterno", "desc": "Derrota a Eclipse junto a la Nave Nodriza", "points": 200},
	&"ach_hells_gate_slayer": {"title": "Portales Cerrados", "desc": "Derrota al Nydus de Hell's Gate", "points": 200},
	&"ach_clinton_slayer": {"title": "Desarme Nuclear", "desc": "Derrota al General Clinton en la antena 20", "points": 250},
	&"ach_kerrigan_slayer": {"title": "Caída Celestial", "desc": "Derrota a Celestial Kerrigan", "points": 300},
	&"ach_narud_slayer": {"title": "Fin de los Tiempos", "desc": "Derrota a Narud y concluye la partida", "points": 500},
	&"ach_hero_ascendance": {"title": "Ascensión del Héroe", "desc": "Alcanza el nivel 100 con un héroe", "points": 200},
	&"ach_demiurge": {"title": "Burlar al Destino", "desc": "Evita la muerte usando el bufo Demiurge", "points": 75},
	&"ach_veterancy_master": {"title": "Veterano de Guerra", "desc": "Alcanza el tope de +125 daño élite con una unidad", "points": 100},
	&"ach_mineral_tycoon": {"title": "Magnate del Mineral", "desc": "Acumula 500,000 minerales en una sola partida", "points": 150},
	&"ach_nightmare_survivor": {"title": "Superviviente de Pesadilla", "desc": "Alcanza el nivel 2 en Modo Nightmare", "points": 200},
	&"ach_hardcore_hero": {"title": "Sin Atajos", "desc": "Supera una partida en Modo Hardcore", "points": 350},
	&"ach_wave_13_pressure": {"title": "Punto de Inflexión", "desc": "Vence la oleada programada 13 de la Colmena", "points": 150},
	&"ach_speedrunner": {"title": "Ofensiva Relámpago", "desc": "Destruye 3 nidos Zerg en menos de 5 minutos", "points": 150},
	&"ach_iron_defense": {"title": "Muralla Inexpugnable", "desc": "Termina una partida sin que el Centro de Mando sufra daño", "points": 250},
	&"ach_quantum_field": {"title": "Campo Cuántico", "desc": "Lanza una habilidad con +75% de amplificación mágica", "points": 50},
	&"ach_fueling_up": {"title": "Reposte Completo", "desc": "Completa el evento de la Estación de Combustible", "points": 75},
	&"ach_random_faith": {"title": "Fe en el Destino", "desc": "Gana una partida habiendo elegido Random Hero", "points": 150}
}


## Unlocks an achievement by ID and updates Bank persistence.
## Returns true if freshly unlocked, false if already achieved or nonexistent.
static func unlock_achievement(ach_id: StringName) -> bool:
	if not ACHIEVEMENTS.has(ach_id):
		return false

	var bank: Dictionary = BankManager.load_bank()
	var unlocked_list: Array = bank.get("achievements_unlocked", [])

	if unlocked_list.has(str(ach_id)):
		return false # Already completed

	unlocked_list.append(str(ach_id))
	bank["achievements_unlocked"] = unlocked_list

	var info: Dictionary = ACHIEVEMENTS[ach_id]
	var points: int = info.get("points", 0)
	var title: String = info.get("title", str(ach_id))

	# Update total achievement points cache in bank
	var current_total: int = bank.get("total_achievement_points", 0)
	bank["total_achievement_points"] = current_total + points

	BankManager.save_bank(bank)
	return true


## Computes total unlocked achievement points from bank.
static func get_total_achievement_points() -> int:
	var bank: Dictionary = BankManager.load_bank()
	var total: int = 0
	var unlocked_list: Array = bank.get("achievements_unlocked", [])
	for id_str in unlocked_list:
		var ach_id: StringName = StringName(id_str)
		if ACHIEVEMENTS.has(ach_id):
			total += ACHIEVEMENTS[ach_id].get("points", 0)
	return total


## Checks if Torment difficulty is unlocked (Requires victory in Brutal) (Task 12.8).
static func is_torment_unlocked() -> bool:
	var bank: Dictionary = BankManager.load_bank()
	var unlocked_list: Array = bank.get("achievements_unlocked", [])
	return unlocked_list.has("ach_brutal_conqueror")


## Checks if secret heroes are unlocked (Requires >= 3000 achievement points) (Task 12.9).
static func are_secret_heroes_unlocked() -> bool:
	return get_total_achievement_points() >= 3000
