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

# Structures Signals
signal gate_state_changed(gate: Node, is_open: bool)
signal structure_damaged(structure: Node, current_hp: float, max_hp: float)
signal structure_destroyed(structure: Node)
