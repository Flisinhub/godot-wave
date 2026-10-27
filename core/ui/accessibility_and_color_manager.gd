class_name AccessibilityManager
extends RefCounted

## AccessibilityManager - SFE5 Accessibility & Colorblind Palettes (Task 14.5).
## Provides colorblind category ring styling, UI scale factor adaptation, and action remapping.

enum ColorblindMode {
	NONE = 0,
	PROTANOPIA = 1,
	DEUTERANOPIA = 2,
	TRITANOPIA = 3
}

var colorblind_mode: ColorblindMode = ColorblindMode.NONE
var ui_scale_factor: float = 1.0


func _init(mode: ColorblindMode = ColorblindMode.NONE, scale: float = 1.0) -> void:
	colorblind_mode = mode
	ui_scale_factor = clampf(scale, 0.75, 1.5)


## Resolves category outline color adapted to the selected colorblind profile.
func get_accessible_category_color(category: String) -> Color:
	var cat: String = category.to_lower()

	match colorblind_mode:
		ColorblindMode.NONE:
			match cat:
				"structure": return Color(0.2, 1.0, 0.3) # Verde estándar
				"heroic": return Color(1.0, 0.9, 0.2)   # Amarillo
				"elite", "map_boss": return Color(1.0, 0.55, 0.1) # Naranja
				"boss", "pinnacle_boss": return Color(1.0, 0.2, 0.2) # Rojo
				_: return Color(0.2, 0.95, 1.0)

		ColorblindMode.PROTANOPIA, ColorblindMode.DEUTERANOPIA:
			# Red-Green colorblindness: replaces green/red clashes with high-contrast Cyan/Blue/Magenta/Yellow
			match cat:
				"structure": return Color(0.0, 0.75, 1.0) # Azul cielo
				"heroic": return Color(1.0, 0.95, 0.1)    # Amarillo brillante
				"elite", "map_boss": return Color(0.9, 0.4, 0.95) # Magenta
				"boss", "pinnacle_boss": return Color(1.0, 0.8, 0.0) # Oro de alto contraste
				_: return Color(0.8, 0.8, 0.8)

		ColorblindMode.TRITANOPIA:
			# Blue-Yellow colorblindness: uses Red, Teal, Pink
			match cat:
				"structure": return Color(0.1, 0.9, 0.7) # Teal
				"heroic": return Color(1.0, 0.4, 0.6)    # Rosa
				"elite", "map_boss": return Color(1.0, 0.6, 0.1) # Naranja
				"boss", "pinnacle_boss": return Color(0.9, 0.1, 0.1) # Rojo puro
				_: return Color(0.9, 0.9, 0.9)

	return Color.WHITE
