class_name LocalizationManager
extends RefCounted

## LocalizationManager - SFE5 Bilingual Spanish/English Dictionary (Task 14.6).
## Delivers localized strings for tactical alerts, UI controls, RPG attributes, and game modes.

const STRINGS_ES: Dictionary = {
	"ui.minerals": "MINERALES",
	"ui.supply": "SUMINISTRO",
	"ui.veterancy": "VETERANÍA",
	"ui.command_center": "CENTRO DE MANDO",
	"ui.hero_fallen": "¡HÉROE CAÍDO! REVIVIENDO EN: %d s",
	"ui.alert_assault": "¡ALERTA! ASALTO DE LA COLMENA EN %d s",
	"ui.alert_drop_pod": "¡DROP POD DETECTADO!",
	"ui.alert_nydus": "¡TEMBLOR SUBTERRÁNEO! Nydus emergiendo",
	"ui.btn_deploy": "DESPLEGAR",
	"ui.btn_cancel": "CANCELAR",
	"mode.classic": "Supervivencia Clásica",
	"mode.hardcore": "Modo Extremo (Hardcore)",
	"mode.nightmare": "Modo Pesadilla (Nightmare)",
	"mode.torment": "Modo Tormento"
}

const STRINGS_EN: Dictionary = {
	"ui.minerals": "MINERALS",
	"ui.supply": "SUPPLY",
	"ui.veterancy": "VETERANCY",
	"ui.command_center": "COMMAND CENTER",
	"ui.hero_fallen": "HERO FALLEN! REVIVING IN: %d s",
	"ui.alert_assault": "WARNING! HIVE ASSAULT IN %d s",
	"ui.alert_drop_pod": "ORBITAL DROP POD DETECTED!",
	"ui.alert_nydus": "SEISMIC TREMOR! Nydus emerging",
	"ui.btn_deploy": "DEPLOY",
	"ui.btn_cancel": "CANCEL",
	"mode.classic": "Classic Survival",
	"mode.hardcore": "Hardcore Mode",
	"mode.nightmare": "Nightmare Mode",
	"mode.torment": "Torment Mode"
}

var current_locale: String = "es"


func _init(locale: String = "es") -> void:
	current_locale = locale.to_lower()


func set_locale(locale: String) -> void:
	current_locale = locale.to_lower()


func get_text(key: String, default_fallback: String = "") -> String:
	var table: Dictionary = STRINGS_ES if current_locale == "es" else STRINGS_EN
	if table.has(key):
		return table[key]
	return default_fallback if default_fallback != "" else key
