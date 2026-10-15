class_name WallSegment
extends StaticBody3D

## WallSegment - Heavy fortified defensive barrier with decoupled visual root and health tracking.

@export var max_health: float = 600.0
@export var structure_name: String = "Perimeter Wall"

@onready var visual_root: Node3D = $VisualRoot

var current_health: float = 600.0

func _ready() -> void:
	add_to_group("structures")
	current_health = max_health


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	SignalBus.structure_damaged.emit(self, current_health, max_health)
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	SignalBus.structure_destroyed.emit(self)
	queue_free()
