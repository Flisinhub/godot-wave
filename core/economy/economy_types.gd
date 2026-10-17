class_name EconomyTypes
extends RefCounted

## EconomyTypes - Central enumeration and data structures for SFE5 Economy and Difficulty Systems.

## Faction alignment enum for hit and bounty attribution provenance.
enum Faction {
	ALLIED = 0,      ## Player heroes, allied marines, base defenses
	HOSTILE = 1,     ## Swarm waves (Zerglings, Roaches, Hydralisks, Ultralisks)
	NEUTRAL = 2,     ## Neutral entities, civilian structures, neutral critters
	ENVIRONMENT = 3, ## Environmental hazards (lava vents, acid geysers, orbital debris)
	ROGUE = 4        ## Rogue hybrids, corrupted mercenaries, renegade factions
}

## Compatibility aliases matching SC2 / survey conventions
const ENEMY_SWARM: int = Faction.HOSTILE
const HOSTILE_ROGUE: int = Faction.ROGUE
const ENVIRONMENTAL: int = Faction.ENVIRONMENT

## 5-Tier dynamic difficulty scaling system modulating income, enemy stats, and upgrade cadence.
enum DifficultyTier {
	CASUAL = 0,  ## 1.50x income, 0.75x enemy stats, 180s upgrade cadence
	NORMAL = 1,  ## 1.00x income, 1.00x enemy stats, 120s upgrade cadence
	HARD = 2,    ## 0.80x income, 1.30x enemy stats,  90s upgrade cadence
	BRUTAL = 3,  ## 0.65x income, 1.75x enemy stats,  60s upgrade cadence
	TORMENT = 4  ## 0.50x income, 2.50x enemy stats,  40s upgrade cadence
}

## Expose KillContext class through EconomyTypes
const KillContext = preload("res://core/economy/kill_context.gd")
