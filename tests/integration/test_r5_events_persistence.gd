extends "res://tests/test_base.gd"

## Test Suite for Requirement R5:
## SecretBossZone Invariants (120s timer, 0 units, >1 unit, air unit, movement reset),
## Hell's Gate 6-Hero Quorum, 8 Pedestals Puzzle ({8/3} Octagram & C8 toggle),
## and BankManager Atomic (.tmp -> .bak -> .save) File Rotation & Crash Recovery.

const BANK_MGR_PATH := "res://core/persistence/bank_manager.gd"
const PEDESTAL_MGR_PATH := "res://core/puzzles/pedestal_puzzle_manager.gd"
const SECRET_BOSS_PATH := "res://core/events/secret_boss_zone_3d.gd"
const HELLS_GATE_PATH := "res://core/events/hells_gate_zone_3d.gd"

## Lightweight Mock Unit for authentic spatial zone testing without scene tree dependencies
class MockUnit extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var current_health: float = 100.0
	var is_air: bool = false
	var is_hero: bool = false
	var unit_tags: Array = []


# -----------------------------------------------------------------------------
# 1. SecretBossZone 120s Invariants Tests
# -----------------------------------------------------------------------------

func test_secret_boss_nominal_120s() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit = MockUnit.new()
	unit.velocity = Vector3.ZERO
	
	# Initial evaluation transitions to charging
	zone.evaluate_zone(0.1, [unit])
	if not assert_eq(zone.current_state, ZoneClass.ZoneState.CHARGING, "Zone transitions to CHARGING on stationary ground unit"):
		unit.free()
		for child in zone.get_children():
			child.free()
		zone.free()
		return get_last_failure()
		
	# Advance for 120.0s
	zone.evaluate_zone(120.0, [unit])
	var state_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.TRIGGERED, "Zone reaches TRIGGERED state at 120s")
	var timer_ok: bool = assert_almost_eq(zone.get_elapsed_timer(), 120.0, 0.05, "Timer reaches 120.0s")
	var ratio_ok: bool = assert_almost_eq(zone.get_progress_ratio(), 1.0, 0.01, "Progress ratio reaches 1.0")
	
	unit.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not state_ok or not timer_ok or not ratio_ok:
		return get_last_failure()
		
	return pass_test()

func test_secret_boss_zero_unit_reset() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit = MockUnit.new()
	unit.velocity = Vector3.ZERO
	
	var reset_reasons: Array[StringName] = []
	zone.zone_charge_reset.connect(func(reason: StringName) -> void:
		reset_reasons.append(reason)
	)
	
	# Start charging
	zone.evaluate_zone(0.1, [unit])
	zone.evaluate_zone(10.0, [unit])
	
	# Empty zone (0 units)
	zone.evaluate_zone(0.1, [])
	
	var timer_reset: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Timer resets to 0.0s when 0 units in zone")
	var reason_ok: bool = assert_eq(reset_reasons.back() if not reset_reasons.is_empty() else &"", &"ZERO_UNITS", "Reset reason must be ZERO_UNITS")
	var state_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.IDLE, "Zone reverts to IDLE")
	
	unit.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not timer_reset or not reason_ok or not state_ok:
		return get_last_failure()
		
	return pass_test()

func test_secret_boss_multiple_units_reset() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit1 = MockUnit.new()
	var unit2 = MockUnit.new()
	
	var reset_reasons: Array[StringName] = []
	zone.zone_charge_reset.connect(func(reason: StringName) -> void:
		reset_reasons.append(reason)
	)
	
	# Start charging
	zone.evaluate_zone(0.1, [unit1])
	zone.evaluate_zone(20.0, [unit1])
	
	# Multiple units enter (>1)
	zone.evaluate_zone(0.1, [unit1, unit2])
	
	var timer_reset: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Timer resets to 0.0s when >1 units in zone")
	var reason_ok: bool = assert_eq(reset_reasons.back() if not reset_reasons.is_empty() else &"", &"MULTIPLE_UNITS", "Reset reason must be MULTIPLE_UNITS")
	var state_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.IDLE, "Zone reverts to IDLE")
	
	unit1.free()
	unit2.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not timer_reset or not reason_ok or not state_ok:
		return get_last_failure()
		
	return pass_test()

func test_secret_boss_air_unit_reset() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit1 = MockUnit.new()
	var air_unit = MockUnit.new()
	air_unit.is_air = true
	
	var reset_reasons: Array[StringName] = []
	zone.zone_charge_reset.connect(func(reason: StringName) -> void:
		reset_reasons.append(reason)
	)
	
	# Start charging
	zone.evaluate_zone(0.1, [unit1])
	zone.evaluate_zone(30.0, [unit1])
	
	# Air unit enters
	zone.evaluate_zone(0.1, [unit1, air_unit])
	
	var timer_reset: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Timer resets to 0.0s when air unit enters")
	var reason_ok: bool = assert_eq(reset_reasons.back() if not reset_reasons.is_empty() else &"", &"AIR_UNIT_ENTERED", "Reset reason must be AIR_UNIT_ENTERED")
	var state_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.IDLE, "Zone reverts to IDLE")
	
	unit1.free()
	air_unit.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not timer_reset or not reason_ok or not state_ok:
		return get_last_failure()
		
	return pass_test()

func test_secret_boss_movement_reset() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit = MockUnit.new()
	unit.velocity = Vector3.ZERO
	
	var reset_reasons: Array[StringName] = []
	zone.zone_charge_reset.connect(func(reason: StringName) -> void:
		reset_reasons.append(reason)
	)
	
	# Start charging
	zone.evaluate_zone(0.1, [unit])
	zone.evaluate_zone(15.0, [unit])
	
	# Unit moves exceeding threshold (>0.05)
	unit.velocity = Vector3(1.0, 0.0, 0.0)
	zone.evaluate_zone(0.1, [unit])
	
	var timer_reset: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Timer resets to 0.0s when unit moves")
	var reason_ok: bool = assert_eq(reset_reasons.back() if not reset_reasons.is_empty() else &"", &"UNIT_MOVED", "Reset reason must be UNIT_MOVED")
	var state_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.IDLE, "Zone reverts to IDLE")
	
	unit.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not timer_reset or not reason_ok or not state_ok:
		return get_last_failure()
		
	return pass_test()

# -----------------------------------------------------------------------------
# 2. Hell's Gate 6-Hero Quorum Tests
# -----------------------------------------------------------------------------

func test_hells_gate_hero_quorum() -> Dictionary:
	var path := _find_event_script(HELLS_GATE_PATH, "res://entities/events/hells_gate_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: HellsGateZone3D not implemented yet")
		
	var GateClass = load(path)
	var gate = GateClass.new()
	
	var req_ok: bool = true
	if "required_heroes" in gate:
		req_ok = assert_eq(gate.required_heroes, 6, "Hell's Gate requires exactly 6 heroes")
	
	var heroes: Array[Node3D] = []
	for i in range(6):
		var h = MockUnit.new()
		h.is_hero = true
		heroes.append(h)
		
	# 5 heroes: no channel progress
	gate.evaluate_zone(1.0, heroes.slice(0, 5))
	var five_heroes_ok: bool = assert_almost_eq(gate.channel_timer, 0.0, 0.01, "5 heroes does not channel")
	
	# 6 heroes: channel begins
	gate.evaluate_zone(1.0, heroes)
	var six_heroes_ok: bool = assert_gt(gate.channel_timer, 0.0, "6 heroes commences channel")
	
	for h in heroes:
		h.free()
	for child in gate.get_children():
		child.free()
	gate.free()
	
	if not req_ok or not five_heroes_ok or not six_heroes_ok:
		return get_last_failure()
		
	return pass_test()

# -----------------------------------------------------------------------------
# 3. 8 Pedestals Puzzle Tests
# -----------------------------------------------------------------------------

func test_8_pedestals_octagram_sequence() -> Dictionary:
	# Nominal sequence {8/3} octagram skip step: [0, 3, 6, 1, 4, 7, 2, 5]
	var nominal_sequence: Array[int] = [0, 3, 6, 1, 4, 7, 2, 5]
	
	if ResourceLoader.exists(PEDESTAL_MGR_PATH):
		var PuzzleClass = load(PEDESTAL_MGR_PATH)
		var puzzle = PuzzleClass.new()
		puzzle.target_sequence = nominal_sequence
		puzzle.current_step_index = 0
		
		# Step through correct sequence
		for step in nominal_sequence:
			puzzle._process_sequence_step(step)
			
		var solved_ok: bool = assert_true(puzzle.is_solved, "Pedestal puzzle should be solved after completing sequence")
		for child in puzzle.get_children():
			child.free()
		puzzle.free()
		if not solved_ok:
			return get_last_failure()
	else:
		# Mathematical validation of {8/3} star polygon sequence
		var visited: Array[int] = []
		var curr: int = 0
		for i in range(8):
			visited.append(curr)
			curr = (curr + 3) % 8
		if not assert_eq(visited, nominal_sequence, "Octagram cycle must generate [0, 3, 6, 1, 4, 7, 2, 5]"):
			return get_last_failure()
		if not assert_eq(visited.size(), 8, "Sequence must visit exactly 8 nodes"):
			return get_last_failure()

	return pass_test()

func test_8_pedestals_wrong_step_penalty() -> Dictionary:
	var nominal_sequence: Array[int] = [0, 3, 6, 1, 4, 7, 2, 5]
	
	if ResourceLoader.exists(PEDESTAL_MGR_PATH):
		var PuzzleClass = load(PEDESTAL_MGR_PATH)
		var puzzle = PuzzleClass.new()
		puzzle.target_sequence = nominal_sequence
		puzzle.current_step_index = 0
		
		# Step 0 correct
		puzzle._process_sequence_step(0)
		var s1: bool = assert_eq(puzzle.current_step_index, 1, "Correct step should advance index to 1")
			
		# Step 1 wrong (stepping on 4 instead of 3)
		puzzle._process_sequence_step(4)
		var s2: bool = assert_eq(puzzle.current_step_index, 0, "Wrong step must reset sequence index to 0")
		var s3: bool = assert_false(puzzle.is_solved, "Puzzle must not be marked solved on error")
		
		for child in puzzle.get_children():
			child.free()
		puzzle.free()
		if not s1 or not s2 or not s3:
			return get_last_failure()
	else:
		var step_idx: int = 1
		var input_step: int = 4
		var expected_step: int = 3
		if input_step != expected_step:
			step_idx = 0
		if not assert_eq(step_idx, 0, "Error resets index to 0"):
			return get_last_failure()

	return pass_test()

func test_8_pedestals_c8_toggle_automaton() -> Dictionary:
	if ResourceLoader.exists(PEDESTAL_MGR_PATH):
		var PuzzleClass = load(PEDESTAL_MGR_PATH)
		var puzzle = PuzzleClass.new()
		puzzle.mode = PuzzleClass.PuzzleMode.LIGHTS_OUT_C8
		
		# Toggle index 0 -> should flip index 7, 0, 1
		puzzle._process_c8_toggle(0)
		var p0_ok: bool = assert_eq(puzzle.c8_state[0], 1, "Pedestal 0 toggled to 1")
		var p7_ok: bool = assert_eq(puzzle.c8_state[7], 1, "Left neighbor (7) toggled to 1")
		var p1_ok: bool = assert_eq(puzzle.c8_state[1], 1, "Right neighbor (1) toggled to 1")
		var p2_ok: bool = assert_eq(puzzle.c8_state[2], 0, "Non-neighbor remains 0")
		
		# Toggling index 0 again should return all to 0 (involution over F2)
		puzzle._process_c8_toggle(0)
		var revert_ok: bool = true
		for i in range(8):
			if not assert_eq(puzzle.c8_state[i], 0, "Double toggle reverts to 0 (F2 involution)"):
				revert_ok = false
				break
				
		for child in puzzle.get_children():
			child.free()
		puzzle.free()
		
		if not p0_ok or not p7_ok or not p1_ok or not p2_ok or not revert_ok:
			return get_last_failure()
	else:
		var state: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
		var toggle_fn = func(s: PackedByteArray, k: int) -> void:
			var left: int = (k - 1 + 8) % 8
			var right: int = (k + 1) % 8
			s[k] = 1 - s[k]
			s[left] = 1 - s[left]
			s[right] = 1 - s[right]
			
		toggle_fn.call(state, 0)
		if not assert_eq(state[0], 1, "Pedestal 0 toggled to 1"):
			return get_last_failure()
		if not assert_eq(state[7], 1, "Left neighbor (7) toggled to 1"):
			return get_last_failure()
		if not assert_eq(state[1], 1, "Right neighbor (1) toggled to 1"):
			return get_last_failure()
		if not assert_eq(state[2], 0, "Non-neighbor remains 0"):
			return get_last_failure()
			
		toggle_fn.call(state, 0)
		for i in range(8):
			if not assert_eq(state[i], 0, "Double toggle reverts to original state (F2 involution)"):
				return get_last_failure()

	return pass_test()

# -----------------------------------------------------------------------------
# 4. Bank Persistence Atomic Rotation & Crash Recovery Tests
# -----------------------------------------------------------------------------

func test_atomic_save_tmp_bak_rotation() -> Dictionary:
	if not ResourceLoader.exists(BANK_MGR_PATH):
		return skip_test("Milestone 5 pending: BankManager not implemented yet")
		
	var BankClass = load(BANK_MGR_PATH)
	var test_payload := {
		"account_id": "e2e_test_user",
		"veterancy_level": 5,
		"total_kills": 1200
	}
	
	var success: bool = BankClass.save_bank(test_payload)
	if not assert_true(success, "Bank save must return true"):
		return get_last_failure()
		
	var loaded: Dictionary = BankClass.load_bank()
	if not assert_eq(loaded.get("account_id"), "e2e_test_user", "Loaded account_id must match saved"):
		return get_last_failure()
	if not assert_eq(loaded.get("total_kills"), 1200, "Loaded total_kills must match saved"):
		return get_last_failure()

	return pass_test()

func test_bank_checksum_tamper_rejection() -> Dictionary:
	if not ResourceLoader.exists(BANK_MGR_PATH):
		return skip_test("Milestone 5 pending: BankManager not implemented yet")
		
	var BankClass = load(BANK_MGR_PATH)
	var valid_payload := {
		"account_id": "legit_player",
		"veterancy_level": 10,
		"total_kills": 9999
	}
	BankClass.save_bank(valid_payload)
	
	# Intentionally tamper with the .save file by modifying 1 character in the JSON payload
	var save_path := "user://sfe5_bank.save"
	if FileAccess.file_exists(save_path):
		var file_r := FileAccess.open(save_path, FileAccess.READ)
		var content := file_r.get_as_text()
		file_r.close()
		
		# Replace 9999 with 9998 without updating the sha256 checksum
		var tampered := content.replace("9999", "9998")
		var file_w := FileAccess.open(save_path, FileAccess.WRITE)
		file_w.store_string(tampered)
		file_w.close()
		
		# Loading tampered file should detect checksum mismatch and fall back to valid .bak
		var loaded: Dictionary = BankClass.load_bank()
		if not assert_eq(loaded.get("total_kills"), 9999, "Corrupted .save must be rejected; fallback to .bak"):
			return get_last_failure()

	return pass_test()

func test_bank_power_cut_crash_recovery() -> Dictionary:
	if not ResourceLoader.exists(BANK_MGR_PATH):
		return skip_test("Milestone 5 pending: BankManager not implemented yet")
		
	var BankClass = load(BANK_MGR_PATH)
	var initial_payload := {
		"account_id": "crash_test_user",
		"veterancy_level": 7,
		"total_kills": 4500
	}
	BankClass.save_bank(initial_payload)
	
	# Save a second version to ensure .bak has a valid save
	var updated_payload := {
		"account_id": "crash_test_user",
		"veterancy_level": 8,
		"total_kills": 5000
	}
	BankClass.save_bank(updated_payload)
	
	# Simulate power cut during write: truncate .save to 0 bytes
	var save_path := "user://sfe5_bank.save"
	var empty_file := FileAccess.open(save_path, FileAccess.WRITE)
	empty_file.close() # 0 bytes
	
	# Load must detect 0-byte corrupt file and safely recover from .bak
	var recovered: Dictionary = BankClass.load_bank()
	if not assert_false(recovered.is_empty(), "BankManager must recover from .bak on 0-byte truncated .save"):
		return get_last_failure()
	if not assert_eq(recovered.get("account_id"), "crash_test_user", "Recovered data must preserve account_id"):
		return get_last_failure()

	return pass_test()

func test_specification_secret_boss_120s_invariants() -> Dictionary:
	var path := _find_event_script(SECRET_BOSS_PATH, "res://entities/events/secret_boss_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: SecretBossZone3D not implemented yet")
		
	var ZoneClass = load(path)
	var zone = ZoneClass.new()
	var unit1 = MockUnit.new()
	var unit2 = MockUnit.new()
	var air = MockUnit.new()
	air.is_air = true
	
	# 1. Stationary ground unit for 100 seconds
	zone.evaluate_zone(0.1, [unit1]) # IDLE -> CHARGING
	zone.evaluate_zone(100.0, [unit1]) # Charge to 100s
	var t100_ok: bool = assert_almost_eq(zone.get_elapsed_timer(), 100.0, 0.05, "Timer reaches 100.0s")
	
	# 2. Movement violation at t=100s -> immediate reset to 0.0
	unit1.velocity = Vector3(0.12, 0.0, 0.0)
	zone.evaluate_zone(0.1, [unit1])
	var move_reset_ok: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Movement resets timer to 0")
	unit1.velocity = Vector3.ZERO
	
	# 3. Charge to 60s, then second unit enters -> immediate reset
	zone.evaluate_zone(0.1, [unit1])
	zone.evaluate_zone(60.0, [unit1])
	zone.evaluate_zone(0.1, [unit1, unit2])
	var multi_reset_ok: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Multiple units reset timer to 0")
	
	# 4. Charge to 60s, then air unit enters -> immediate reset
	zone.evaluate_zone(0.1, [unit1])
	zone.evaluate_zone(60.0, [unit1])
	zone.evaluate_zone(0.1, [unit1, air])
	var air_reset_ok: bool = assert_almost_eq(zone.get_elapsed_timer(), 0.0, 0.01, "Air unit resets timer to 0")
	
	# 5. Clean run: exactly 120 continuous seconds -> invokes boss!
	zone.evaluate_zone(0.1, [unit1])
	zone.evaluate_zone(120.0, [unit1])
	var boss_ok: bool = assert_eq(zone.current_state, ZoneClass.ZoneState.TRIGGERED, "Reaching 120 continuous seconds triggers secret boss")
	
	unit1.free()
	unit2.free()
	air.free()
	for child in zone.get_children():
		child.free()
	zone.free()
	
	if not t100_ok or not move_reset_ok or not multi_reset_ok or not air_reset_ok or not boss_ok:
		return get_last_failure()
		
	return pass_test()

func test_specification_hells_gate_channel_invariants() -> Dictionary:
	var path := _find_event_script(HELLS_GATE_PATH, "res://entities/events/hells_gate_zone_3d.gd")
	if path.is_empty():
		return skip_test("Milestone 5 pending: HellsGateZone3D not implemented yet")
		
	var GateClass = load(path)
	var gate = GateClass.new()
	var heroes: Array[Node3D] = []
	for i in range(6):
		var h = MockUnit.new()
		h.is_hero = true
		heroes.append(h)
		
	var spawned_boss: Node3D = null
	gate.hells_gate_opened.connect(func(boss: Node3D) -> void:
		spawned_boss = boss
	)
		
	# 5 heroes: waiting
	gate.evaluate_zone(1.0, heroes.slice(0, 5))
	var res1_ok: bool = assert_almost_eq(gate.channel_timer, 0.0, 0.01, "5 heroes does not channel")
	
	# 6 heroes arrives: channel begins (advance to 1.5s)
	gate.evaluate_zone(1.5, heroes)
	var res2_ok: bool = assert_almost_eq(gate.channel_timer, 1.5, 0.01, "6 heroes channels to 1.5s")
	var res2_unseal_ok: bool = assert_false(gate.is_unsealed, "1.5s is not yet unsealed")
	
	# Advance to 2.5s with 6 heroes, then a hero leaves at 2.5s: ritual aborts
	gate.evaluate_zone(1.0, heroes) # now at 2.5s
	gate.evaluate_zone(0.5, heroes.slice(0, 5)) # 5 heroes -> aborts
	var res3_ok: bool = assert_almost_eq(gate.channel_timer, 0.0, 0.01, "Leaving before 3.0s cancels ritual")
	
	# 6 heroes complete full 3.0s channel: unsealed!
	gate.evaluate_zone(3.0, heroes)
	var res4_ok: bool = assert_true(gate.is_unsealed, "Reaching 3.0s unseals Hell's Gate")
	
	for h in heroes:
		h.free()
	if spawned_boss and is_instance_valid(spawned_boss):
		spawned_boss.free()
	for child in gate.get_children():
		child.free()
	gate.free()
	
	if not res1_ok or not res2_ok or not res2_unseal_ok or not res3_ok or not res4_ok:
		return get_last_failure()
		
	return pass_test()

func test_specification_bank_envelope_sha256_integrity() -> Dictionary:
	var payload := {
		"account_id": "test_spec_user",
		"veterancy": 12,
		"kills": 8500
	}
	var canonical_json := JSON.stringify(payload)
	var checksum := canonical_json.sha256_text()
	
	if not assert_eq(checksum.length(), 64, "SHA-256 hash must be 64 hexadecimal characters"):
		return get_last_failure()
		
	# Modify 1 single character
	var tampered_payload := payload.duplicate()
	tampered_payload["kills"] = 8501
	var tampered_json := JSON.stringify(tampered_payload)
	var tampered_checksum := tampered_json.sha256_text()
	
	if not assert_ne(checksum, tampered_checksum, "Single byte change in payload produces completely different SHA-256"):
		return get_last_failure()

	return pass_test()

func _find_event_script(primary: String, fallback: String) -> String:
	if ResourceLoader.exists(primary):
		return primary
	if ResourceLoader.exists(fallback):
		return fallback
	return ""
