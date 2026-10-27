class_name EventData
extends Resource

## EventData - SFE5 In-Game Events & Timed Invasions Schema.
## Defines drop pods, timed attacks, secret portals, and protoss phases.

@export_group("Identity")
@export var id: StringName = &"event"
@export var event_name: String = "Timed Event"
@export_multiline var description: String = ""

@export_group("Trigger & Timing")
@export_enum("timer", "wave_milestone", "spawner_cleared", "boss_death") var trigger_type: String = "timer"
@export var trigger_delay_seconds: float = 300.0 # e.g. 5 min timed attack
@export var recurring_interval_seconds: float = 0.0 # 0 = One shot

@export_group("Conditions & Rewards")
@export var conditions: Array[String] = []
@export var rewards: Dictionary = {"minerals": 2500, "xp": 1000}
@export var spawns: Array[Resource] = [] # Units or hazards spawned by event
