@warning_ignore("unused_signal")
extends Node

## SignalBus - Central Event Bus for RTS Architecture
## Ensures complete decoupling between entities, camera, UI, and game controllers.

# Selection Signals
signal units_selected(units: Array)
signal units_deselected()

# Movement & Orders
signal move_command_issued(target_position: Vector3)

# Entity State Signals
signal unit_health_changed(unit: Node, current_hp: float, max_hp: float)
signal unit_died(unit: Node)

# Combat & Wave Signals
signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)
signal wave_enemy_count_changed(alive_count: int)
signal enemy_died(enemy: Node, reward: int)
signal base_destroyed()

# Timed Events & External Pressure (Fase 8)
signal scheduled_attack_warned(wave_index: int, leader_name: String, seconds_left: float, direction: Vector3)
signal scheduled_attack_started(wave_index: int, leader_data: Dictionary)
signal drop_pod_incoming(target_position: Vector3, delay: float)
signal drop_pod_impacted(target_position: Vector3)
signal nydus_tremor_alert(crater_index: int, position: Vector3, tier_name: String)

# Structures Signals
signal gate_state_changed(gate: Node, is_open: bool)
signal structure_damaged(structure: Node, current_hp: float, max_hp: float)
signal structure_destroyed(structure: Node)
