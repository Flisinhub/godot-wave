class_name BunkerStructure
extends StaticBody3D

## BunkerStructure - Fortified infantry shelter providing 25% passive structural mitigation.
## Implements Requirement R2 / M6 perimeter defensive integration.

@export var max_health: float = 750.0
@export var structure_name: String = "Terran Bunker"

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var health_bar: Node = get_node_or_null("HealthBar3D")

var current_health: float = 750.0


func _ready() -> void:
	add_to_group("structures")
	add_to_group("bunkers")
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	SignalBus.structure_damaged.emit(self, current_health, max_health)
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	SignalBus.structure_destroyed.emit(self)
	queue_free()
