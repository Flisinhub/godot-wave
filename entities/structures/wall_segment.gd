class_name WallSegment
extends StaticBody3D

## WallSegment - Heavy fortified defensive barrier with decoupled visual root and health tracking.

@export var max_health: float = 600.0
@export var structure_name: String = "Perimeter Wall"

@onready var visual_root: Node3D = $VisualRoot
@onready var health_bar: HealthBar3D = $HealthBar3D

var current_health: float = 600.0


func _ready() -> void:
	add_to_group("structures")
	current_health = max_health
	if health_bar:
		health_bar.setup(current_health, max_health)


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar:
		health_bar.update_health(current_health, max_health)
	SignalBus.structure_damaged.emit(self, current_health, max_health)
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	SignalBus.structure_destroyed.emit(self)
	queue_free()
