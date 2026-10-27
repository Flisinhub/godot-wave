class_name MatchCodeReader
extends RefCounted

## MatchCodeReader - SFE5 Match Code Encoder / Decoder (Task 9.16).
## Emulates the iconic /match command to inspect match seeds, layouts, and share game setups.

const PREFIX: String = "SFE5"


## Generates an authentic match code string from a seed and optional mode flag.
static func generate_match_code(seed_val: int, mode_suffix: String = "NM") -> String:
	return "%s-%06d-%s" % [PREFIX, absi(seed_val) % 1000000, mode_suffix.to_upper()]


## Parses a match code string and extracts seed and layout parameters.
static func parse_match_code(code: String) -> Dictionary:
	var clean: String = code.strip_edges().to_upper()
	var parts: PackedStringArray = clean.split("-")

	if parts.size() < 3 or parts[0] != PREFIX:
		return {
			"is_valid": false,
			"error": "Código de partida no reconocido (formato esperado: SFE5-XXXXXX-MODE)",
			"seed": 0,
			"mode": ""
		}

	var parsed_seed: int = parts[1].to_int()
	var mode: String = parts[2]

	return {
		"is_valid": true,
		"seed": parsed_seed,
		"mode": mode,
		"code": clean,
		"summary": "Partida SFE5 Semilla #%d (Modo %s)" % [parsed_seed, mode]
	}
