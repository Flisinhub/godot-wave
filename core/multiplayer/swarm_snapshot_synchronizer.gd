class_name SwarmSnapshotSynchronizer
extends RefCounted

## SwarmSnapshotSynchronizer - SFE5 Compressed Network Swarm Replication (Task 13.5).
## Packs thousands of swarm units into bandwidth-efficient binary buffers for client interpolation.

# Pack layout per unit:
# [pos_x: float32 (4B)][pos_z: float32 (4B)][hp_pct: uint8 (1B)][state_flags: uint8 (1B)] = 10 Bytes per unit.
const BYTES_PER_UNIT: int = 10


## Packs an array of units into a compact binary buffer.
static func pack_snapshot(units_data: Array, timestamp: float = 0.0) -> PackedByteArray:
	var count: int = units_data.size()
	var buffer := StreamPeerBuffer.new()
	buffer.put_float(timestamp)
	buffer.put_u16(count)

	for unit in units_data:
		var pos: Vector3 = unit.get("position", Vector3.ZERO)
		var hp_ratio: float = clampf(unit.get("health_ratio", 1.0), 0.0, 1.0)
		var flags: int = unit.get("flags", 0)

		buffer.put_float(pos.x)
		buffer.put_float(pos.z)
		buffer.put_u8(int(hp_ratio * 255.0))
		buffer.put_u8(flags)

	return buffer.data_array


## Unpacks a compact binary buffer back into array of unit records.
static func unpack_snapshot(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 6:
		return {"timestamp": 0.0, "units": []}

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	var timestamp: float = buffer.get_float()
	var count: int = buffer.get_u16()

	var units: Array[Dictionary] = []
	for i in range(count):
		if buffer.get_available_bytes() < BYTES_PER_UNIT:
			break
		var px: float = buffer.get_float()
		var pz: float = buffer.get_float()
		var hp_pct: float = float(buffer.get_u8()) / 255.0
		var flags: int = buffer.get_u8()

		units.append({
			"position": Vector3(px, 0.0, pz),
			"health_ratio": hp_pct,
			"flags": flags
		})

	return {
		"timestamp": timestamp,
		"count": units.size(),
		"units": units
	}


## Performs linear interpolation between two snapshots for smooth client rendering.
static func interpolate_positions(prev_pos: Vector3, next_pos: Vector3, weight: float) -> Vector3:
	return prev_pos.lerp(next_pos, clampf(weight, 0.0, 1.0))
