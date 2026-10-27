class_name CalendarEventManager
extends RefCounted

## CalendarEventManager - Real-world date-driven calendar events for SFE5 (Fase 16, Task 16.3).
## Detects seasonal events (Christmas, New Year, April Fools, Halloween)
## and provides visual themes, ambient modifiers, and event multipliers.

enum EventTheme {
	NONE = 0,
	CHRISTMAS = 1,
	NEW_YEAR = 2,
	APRIL_FOOLS = 3,
	HALLOWEEN = 4
}

var current_theme: int = EventTheme.NONE
var theme_name: String = "Normal"
var mineral_multiplier: float = 1.0
var score_multiplier: float = 1.0
var enemy_speed_modifier: float = 1.0
var decorative_vfx_enabled: bool = false
var ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)


func _init(custom_date: Dictionary = {}) -> void:
	refresh_event_from_date(custom_date)


## Refreshes event according to real system date (or custom dictionary for testing).
## custom_date format: {"month": 12, "day": 25}
func refresh_event_from_date(custom_date: Dictionary = {}) -> void:
	var date: Dictionary = custom_date
	if date.is_empty():
		date = Time.get_datetime_dict_from_system()

	var month: int = int(date.get("month", 1))
	var day: int = int(date.get("day", 1))

	# 1. New Year (Dec 31 - Jan 2)
	if (month == 12 and day == 31) or (month == 1 and day <= 2):
		current_theme = EventTheme.NEW_YEAR
		theme_name = "New Year Celebration"
		mineral_multiplier = 1.0
		score_multiplier = 1.15  ## +15% victory points
		enemy_speed_modifier = 1.0
		decorative_vfx_enabled = true
		ambient_color = Color(1.1, 1.1, 1.3, 1.0)  ## Festive crystalline tint
		return

	# 2. Christmas / Winter Festival (Dec 15 - Jan 5)
	if (month == 12 and day >= 15) or (month == 1 and day <= 5):
		current_theme = EventTheme.CHRISTMAS
		theme_name = "Festive Winter"
		mineral_multiplier = 1.10  ## +10% passive minerals
		score_multiplier = 1.0
		enemy_speed_modifier = 1.0
		decorative_vfx_enabled = true
		ambient_color = Color(0.9, 0.95, 1.1, 1.0)  ## Snowy cool blue tint
		return

	# 3. April Fools (April 1st)
	if month == 4 and day == 1:
		current_theme = EventTheme.APRIL_FOOLS
		theme_name = "April Fools"
		mineral_multiplier = 1.0
		score_multiplier = 1.0
		enemy_speed_modifier = 0.95  ## Slight comical pacing
		decorative_vfx_enabled = true
		ambient_color = Color(1.05, 0.9, 1.1, 1.0)  ## Quirky magenta hue
		return

	# 4. Halloween (Oct 25 - Nov 2)
	if (month == 10 and day >= 25) or (month == 11 and day <= 2):
		current_theme = EventTheme.HALLOWEEN
		theme_name = "Blood Moon Halloween"
		mineral_multiplier = 1.0
		score_multiplier = 1.05
		enemy_speed_modifier = 1.05  ## +5% aggressive enemies
		decorative_vfx_enabled = true
		ambient_color = Color(1.2, 0.7, 0.4, 1.0)  ## Spooky orange/crimson tint
		return

	# Default: Normal
	current_theme = EventTheme.NONE
	theme_name = "Standard"
	mineral_multiplier = 1.0
	score_multiplier = 1.0
	enemy_speed_modifier = 1.0
	decorative_vfx_enabled = false
	ambient_color = Color(1.0, 1.0, 1.0, 1.0)


## Helper query methods
func is_holiday_event_active() -> bool:
	return current_theme != EventTheme.NONE


func get_event_summary() -> Dictionary:
	return {
		"theme": current_theme,
		"theme_name": theme_name,
		"mineral_mult": mineral_multiplier,
		"score_mult": score_multiplier,
		"enemy_speed_mult": enemy_speed_modifier,
		"vfx_enabled": decorative_vfx_enabled,
		"ambient_color": ambient_color
	}
