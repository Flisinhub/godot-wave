class_name PinnacleBossCatalog
extends RefCounted

## PinnacleBossCatalog - The 11 Canonical Pinnacle Bosses and Rituals of SFE5 (Tasks 10.6 - 10.16).
## Stores baseline combat stats, ritual specifications, phase triggers, and reward unlocks.

const SummoningRitual = preload("res://core/bosses/summoning_ritual.gd")

const BOSS_DEFINITIONS: Dictionary = {
	&"odin": {
		"id": &"odin",
		"name": "Odin, Titan of Armageddon",
		"hp": 16000.0,
		"armor": 18.0,
		"damage": 120.0,
		"ritual_type": SummoningRitual.RitualType.BEACONS,
		"ritual_count": 3,
		"ritual_desc": "Pisar 3 balizas raciales en la diagonal NO–SE",
		"secret_unit": &"thor_ace",
		"spawn_pos": Vector3(-20.0, 0.0, -20.0)
	},
	&"gorgon": {
		"id": &"gorgon",
		"name": "Gorgon, the Skycleaver",
		"hp": 14000.0,
		"armor": 16.0,
		"damage": 95.0,
		"ritual_type": SummoningRitual.RitualType.STRUCTURE_BUILD,
		"ritual_count": 4,
		"ritual_desc": "Construir 4 estructuras en el perímetro de la antena SR-04",
		"secret_unit": &"battlecruiser_ace",
		"spawn_pos": Vector3(30.0, 0.0, 30.0)
	},
	&"diablo": {
		"id": &"diablo",
		"name": "Diablo, Lord of Terror",
		"hp": 18000.0,
		"armor": 20.0,
		"damage": 140.0,
		"ritual_type": SummoningRitual.RitualType.BEACONS,
		"ritual_count": 2,
		"ritual_desc": "Evento Estación de Gas completado + resistir oleadas",
		"secret_unit": &"hellbat_ace",
		"spawn_pos": Vector3(18.0, 0.0, 35.0)
	},
	&"chaindog": {
		"id": &"chaindog",
		"name": "Chaindog, the Mauler",
		"hp": 13000.0,
		"armor": 14.0,
		"damage": 85.0,
		"ritual_type": SummoningRitual.RitualType.HOLD_POSITION,
		"ritual_count": 1,
		"ritual_desc": "Unidad en las sillas frente a la estatua de Mengsk y mantener zona",
		"secret_unit": &"warhound_ace",
		"spawn_pos": Vector3(-30.0, 0.0, 10.0)
	},
	&"hybrid_behemoth": {
		"id": &"hybrid_behemoth",
		"name": "Hybrid Behemoth",
		"hp": 20000.0,
		"armor": 22.0,
		"damage": 160.0,
		"ritual_type": SummoningRitual.RitualType.OBJECTIVE_DESTRUCTION,
		"ritual_count": 2,
		"ritual_desc": "Mantener posición junto al Cristal Xel'Naga y destruir Cristal del Vacío",
		"secret_unit": &"immortal_ace",
		"spawn_pos": Vector3(0.0, 0.0, 35.0)
	},
	&"hybrid_experimented": {
		"id": &"hybrid_experimented",
		"name": "Hybrid Experimented",
		"hp": 15000.0,
		"armor": 17.0,
		"damage": 110.0,
		"ritual_type": SummoningRitual.RitualType.BEACONS,
		"ritual_count": 1,
		"ritual_desc": "Armonización en la ruta del cristal opuesto",
		"secret_unit": &"colossus_ace",
		"spawn_pos": Vector3(35.0, 0.0, 0.0)
	},
	&"eclipse": {
		"id": &"eclipse",
		"name": "Eclipse, Destroyer of Worlds",
		"hp": 22000.0,
		"armor": 25.0,
		"damage": 180.0,
		"ritual_type": SummoningRitual.RitualType.HOLD_POSITION,
		"ritual_count": 1,
		"ritual_desc": "Unidad sobre el respiradero junto a la Nave Nodriza",
		"secret_unit": &"carrier_ace",
		"spawn_pos": Vector3(40.0, 0.0, -40.0)
	},
	&"hells_gate": {
		"id": &"hells_gate",
		"name": "Hell's Gate Nydus",
		"hp": 17000.0,
		"armor": 20.0,
		"damage": 130.0,
		"ritual_type": SummoningRitual.RitualType.MASS_UNITS,
		"ritual_count": 6,
		"ritual_desc": "6 unidades heroicas junto a Voice of the Abyss",
		"secret_unit": &"brutalisk_ace",
		"spawn_pos": Vector3(38.0, 0.0, 18.0)
	},
	&"general_clinton": {
		"id": &"general_clinton",
		"name": "General Clinton",
		"hp": 24000.0,
		"armor": 24.0,
		"damage": 200.0,
		"ritual_type": SummoningRitual.RitualType.MASS_UNITS,
		"ritual_count": 20,
		"ritual_desc": "20 unidades en la antena '20'; lanza bomba nuclear al caer",
		"secret_unit": &"ghost_ace",
		"spawn_pos": Vector3(-35.0, 0.0, -35.0)
	},
	&"celestial_kerrigan": {
		"id": &"celestial_kerrigan",
		"name": "Celestial Kerrigan",
		"hp": 28000.0,
		"armor": 26.0,
		"damage": 230.0,
		"ritual_type": SummoningRitual.RitualType.SACRIFICE,
		"ritual_count": 1,
		"ritual_desc": "Activar el Elemental Slayn para el renacer celestial de la Reina",
		"secret_unit": &"leviathan_ace",
		"spawn_pos": Vector3(0.0, 0.0, 0.0)
	},
	&"narud": {
		"id": &"narud",
		"name": "Narud, Servant of Amon",
		"hp": 35000.0,
		"armor": 30.0,
		"damage": 280.0,
		"ritual_type": SummoningRitual.RitualType.OBJECTIVE_DESTRUCTION,
		"ritual_count": 4,
		"ritual_desc": "Destruir 4 Vestigios Antiguos (romper invulnerabilidad). Concluye la partida.",
		"secret_unit": &"narud_avatar",
		"spawn_pos": Vector3(45.0, 0.0, -45.0)
	}
}


static func get_all_boss_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k in BOSS_DEFINITIONS.keys():
		ids.append(k)
	return ids


static func get_boss_info(boss_id: StringName) -> Dictionary:
	return BOSS_DEFINITIONS.get(boss_id, {})


static func create_ritual_for_boss(boss_id: StringName) -> SummoningRitual:
	if not BOSS_DEFINITIONS.has(boss_id):
		return null

	var info: Dictionary = BOSS_DEFINITIONS[boss_id]
	var ritual := SummoningRitual.new(
		boss_id,
		info.get("ritual_type", SummoningRitual.RitualType.BEACONS),
		info.get("ritual_count", 3),
		info.get("spawn_pos", Vector3.ZERO)
	)
	ritual.boss_title = info.get("name", "Pinnacle Boss")
	ritual.description = info.get("ritual_desc", "")
	return ritual
