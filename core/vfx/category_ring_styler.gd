class_name CategoryRingStyler
extends RefCounted

## CategoryRingStyler - SFE5 Category Ring Iconography & Palette (Task 6.8).
## Assigns canonical category ring colors:
## - Normal: Green Color(0.2, 0.9, 0.4)
## - Heroic: Yellow Color(1.0, 0.85, 0.2)
## - Elite: Orange Color(1.0, 0.5, 0.1)
## - Boss / Structure: Red Color(0.95, 0.2, 0.2)

static func get_category_color(category: String) -> Color:
	match category.to_lower():
		"normal":
			return Color(0.2, 0.9, 0.4, 1.0)
		"heroic":
			return Color(1.0, 0.85, 0.2, 1.0)
		"elite":
			return Color(1.0, 0.5, 0.1, 1.0)
		"map_boss", "summoned_boss", "pinnacle_boss", "boss", "structure":
			return Color(0.95, 0.2, 0.2, 1.0)
		_:
			return Color(0.2, 0.9, 0.4, 1.0)


static func apply_ring_style(ring_mesh: MeshInstance3D, category: String) -> void:
	if not ring_mesh:
		return
	var col := get_category_color(category)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	ring_mesh.material_override = mat
