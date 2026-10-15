class_name CommandCenter
extends StaticBody3D

## CommandCenter - The central HQ structure of the Terran base.
## Primary objective to protect against enemy waves.

@export var max_health: float = 2000.0
@export var structure_name: String = "Command Center"

@onready var visual_root: Node3D = $VisualRoot
@onready var health_bar: HealthBar3D = $HealthBar3D

var current_health: float = 2000.0


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
		SignalBus.structure_destroyed.emit(self)
		queue_free()
