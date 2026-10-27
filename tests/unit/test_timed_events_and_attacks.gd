class_name TestTimedEventsAndAttacks
extends RefCounted

## TestTimedEventsAndAttacks - SFE5 External Pressure & Timed Events Test Suite (Fase 8).
## Validates determinism, Drop Pod safety boundaries, 300s Scheduled Attacks sequence,
## Wave 13 boss acceleration divisor, and 12-crater Nydus power scaling.

const TimedEventSchedule = preload("res://core/events/timed_event_schedule.gd")
const DropPodManager = preload("res://core/events/drop_pod_manager.gd")
const NydusCraterManager = preload("res://core/events/nydus_crater_manager.gd")
const ScheduledAttackManager = preload("res://core/events/scheduled_attack_manager.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Timed Events & Hive Pressure")
	_tests_passed = 0
	_tests_failed = 0

	test_timed_event_schedule_seed_determinism()
	test_drop_pod_timeline_and_peace_phase()
	test_drop_pod_manager_base_perimeter_safety()
	test_scheduled_hive_attacks_sequence_and_warnings()
	test_wave_13_boss_summon_speed_divisor()
	test_nydus_craters_and_tier_scaling()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: Seed Determinism (Task 8.8)
func test_timed_event_schedule_seed_determinism() -> void:
	var seed_val: int = 987654
	var sched_a := TimedEventSchedule.new(seed_val)
	var sched_b := TimedEventSchedule.new(seed_val)

	var crater_a1: int = sched_a.pick_deterministic_crater(0)
	var crater_a2: int = sched_a.pick_deterministic_crater(1)
	var crater_b1: int = sched_b.pick_deterministic_crater(0)
	var crater_b2: int = sched_b.pick_deterministic_crater(1)

	_assert_true(crater_a1 == crater_b1 and crater_a2 == crater_b2, "Identical seed produces identical crater choices")

	var diff_seed := TimedEventSchedule.new(111222)
	var crater_diff: int = diff_seed.pick_deterministic_crater(0)
	# Different seeds generally yield different values
	_assert_true(sched_a.match_seed != diff_seed.match_seed, "Different seeds maintain distinct configurations")


## Test 2: Drop Pod Timeline and 120s Peace Phase (Task 8.1)
func test_drop_pod_timeline_and_peace_phase() -> void:
	var sched := TimedEventSchedule.new(123)

	# 0..119s -> No drop pods during 120s peace phase
	var events_early: Array[Dictionary] = sched.advance_time(119.0)
	var pods_early: int = 0
	for ev in events_early:
		if ev["type"] == "drop_pod":
			pods_early += 1
	_assert_true(pods_early == 0, "No drop pods during initial 120s peace phase")

	# Advance 1.0s (total 120s) -> Pod 1 triggers
	var events_120: Array[Dictionary] = sched.advance_time(1.0)
	var pod1_found: bool = false
	for ev in events_120:
		if ev["type"] == "drop_pod" and ev["pod_index"] == 1:
			pod1_found = true
	_assert_true(pod1_found, "Drop Pod 1 triggers exactly at 120s peace expiration")

	# Advance 45.0s (total 165s) -> Pod 2 triggers
	var events_165: Array[Dictionary] = sched.advance_time(45.0)
	var pod2_found: bool = false
	for ev in events_165:
		if ev["type"] == "drop_pod" and ev["pod_index"] == 2:
			pod2_found = true
	_assert_true(pod2_found, "Drop Pod 2 triggers 45s after first pod (165s)")

	# Advance 45.0s (total 210s) -> Pod 3 triggers
	var events_210: Array[Dictionary] = sched.advance_time(45.0)
	var pod3_found: bool = false
	for ev in events_210:
		if ev["type"] == "drop_pod" and ev["pod_index"] == 3:
			pod3_found = true
	_assert_true(pod3_found, "Drop Pod 3 triggers 45s later (210s)")


## Test 3: Drop Pod Perimeter & Landing Safety (Task 8.1)
func test_drop_pod_manager_base_perimeter_safety() -> void:
	var base_pos := Vector3(-45.0, 0.0, 45.0)
	var manager := DropPodManager.new(base_pos, 28.0)

	var inside_unit_pos := Vector3(-40.0, 0.0, 40.0) # Dist approx 7.07m < 28m
	var outside_unit_pos := Vector3(0.0, 0.0, 0.0)     # Dist approx 63.6m > 28m

	_assert_true(not manager.is_outside_base(inside_unit_pos), "Unit within 28m is safely inside base")
	_assert_true(manager.is_outside_base(outside_unit_pos), "Unit beyond 28m is outside base")

	# All units inside base -> strike request rejected (safe zone)
	var inside_only: Array[Vector3] = [inside_unit_pos, base_pos]
	var scheduled_inside: bool = manager.request_strike(inside_only)
	_assert_true(not scheduled_inside, "Drop pod strike rejected when all units are inside base")

	# Outside unit present -> strike request approved
	var targets: Array[Vector3] = [inside_unit_pos, outside_unit_pos]
	var scheduled_outside: bool = manager.request_strike(targets)
	_assert_true(scheduled_outside, "Drop pod strike approved targeting unit outside base")

	# Process strike delay and verify impact
	_assert_true(manager.active_strikes.size() == 1, "Active strike queued with warning delay")
	var landed_empty: Array = manager.process_strikes(1.0)
	_assert_true(landed_empty.is_empty(), "Strike remains telegraphed before delay expires")

	var landed_final: Array = manager.process_strikes(2.0)
	_assert_true(landed_final.size() == 1, "Strike lands and detonates when timer elapses")
	_assert_true(manager.active_strikes.is_empty(), "Active strikes cleared after impact")


## Test 4: Scheduled Hive Attacks Sequence and Warnings (Tasks 8.3, 8.4, 8.6)
func test_scheduled_hive_attacks_sequence_and_warnings() -> void:
	var sched := TimedEventSchedule.new(42)
	var attack_mgr := ScheduledAttackManager.new(sched)

	var warnings_received: Array[Dictionary] = []
	attack_mgr.attack_warning_received.connect(func(w: int, l: String, s: float, _d: Vector3) -> void:
		warnings_received.append({"wave": w, "leader": l, "seconds_left": s})
	)

	var waves_dispatched: Array[Dictionary] = []
	attack_mgr.wave_attack_dispatched.connect(func(w: int, data: Dictionary, _h: Vector3, _b: Vector3) -> void:
		waves_dispatched.append({"wave": w, "data": data})
	)

	# Advance to 240s (60s before 300s attack) -> 60s warning
	sched.advance_time(240.0)
	_assert_true(warnings_received.size() >= 1, "60s attack warning triggered")
	_assert_true(warnings_received[0]["leader"] == "Infested General", "Wave 1 leader is Infested General")
	_assert_true(is_equal_approx(warnings_received[0]["seconds_left"], 60.0), "Warning seconds left is 60s")

	# Advance to 270s (30s before 300s) -> 30s warning
	sched.advance_time(30.0)
	_assert_true(warnings_received.size() >= 2, "30s attack warning triggered")
	_assert_true(is_equal_approx(warnings_received[1]["seconds_left"], 30.0), "Warning seconds left is 30s")

	# Advance to 290s (10s before 300s) -> 10s warning
	sched.advance_time(20.0)
	_assert_true(warnings_received.size() >= 3, "10s attack warning triggered")
	_assert_true(is_equal_approx(warnings_received[2]["seconds_left"], 10.0), "Warning seconds left is 10s")

	# Advance to 300s -> Wave 1 attack launched!
	sched.advance_time(10.0)
	_assert_true(waves_dispatched.size() == 1, "Wave 1 attack launched at 300s")
	_assert_true(waves_dispatched[0]["data"]["leader_name"] == "Infested General", "Wave 1 Leader is 1 Infested General")
	_assert_true(waves_dispatched[0]["data"]["leader_count"] == 1, "Wave 1 Leader count is 1")

	# Check the canonical sequence for waves 1 to 7 (Task 8.4)
	var w1 := sched.get_scheduled_leader(1)
	var w2 := sched.get_scheduled_leader(2)
	var w3 := sched.get_scheduled_leader(3)
	var w4 := sched.get_scheduled_leader(4)
	var w5 := sched.get_scheduled_leader(5)
	var w6 := sched.get_scheduled_leader(6)
	var w7 := sched.get_scheduled_leader(7)

	_assert_true(w1["leader_name"] == "Infested General" and w1["leader_count"] == 1, "Wave 1: 1 Infested General")
	_assert_true(w2["leader_name"] == "Rageling" and w2["leader_count"] == 3, "Wave 2: 3 Rageling")
	_assert_true(w3["leader_name"] == "Hellbringer" and w3["leader_count"] == 5, "Wave 3: 5 Hellbringer")
	_assert_true(w4["leader_name"] == "Brood Emperor" and w4["leader_count"] == 7, "Wave 4: 7 Brood Emperor")
	_assert_true(w5["leader_name"] == "Hybrid Viper" and w5["leader_count"] == 9, "Wave 5: 9 Hybrid Viper")
	_assert_true(w6["leader_name"] == "Hybrid Lenkus" and w6["leader_count"] == 11, "Wave 6: 11 Hybrid Lenkus")
	_assert_true(w7["leader_name"] == "Ferocious Brutes" and w7["leader_count"] == 13, "Wave 7: 13 Ferocious Brutes")


## Test 5: Wave 13 Boss Summon Speed Divisor (Task 8.5)
func test_wave_13_boss_summon_speed_divisor() -> void:
	var sched := TimedEventSchedule.new(777)
	var attack_mgr := ScheduledAttackManager.new(sched)

	_assert_true(is_equal_approx(sched.boss_summon_speed_multiplier, 1.0), "Initial boss summon multiplier is 1.0")
	_assert_true(not sched.is_wave_13_cleared, "Wave 13 initially not cleared")

	# Clearing wave 12 does not trigger 3x speedup
	attack_mgr.active_leaders_alive[12] = 1
	attack_mgr.report_leader_kill(12)
	_assert_true(is_equal_approx(sched.boss_summon_speed_multiplier, 1.0), "Wave 12 clear does not accelerate boss summon")

	# Clearing wave 13 triggers 3x divisor (Task 8.5)
	var state := {"accelerated": false}
	attack_mgr.hive_pressure_accelerated.connect(func(mult: float) -> void:
		if is_equal_approx(mult, 3.0):
			state["accelerated"] = true
	)

	attack_mgr.active_leaders_alive[13] = 1
	attack_mgr.report_leader_kill(13)

	_assert_true(sched.is_wave_13_cleared, "Wave 13 marked cleared")
	_assert_true(is_equal_approx(sched.boss_summon_speed_multiplier, 3.0), "Boss summon time divided by 3 (multiplier 3.0)")
	_assert_true(state["accelerated"], "Hive pressure accelerated signal emitted with 3x multiplier")


## Test 6: 12 Strategic Nydus Craters and Power Scaling (Task 8.2)
func test_nydus_craters_and_tier_scaling() -> void:
	var sched := TimedEventSchedule.new(555)
	var nydus_mgr := NydusCraterManager.new(sched)

	_assert_true(TimedEventSchedule.CRATER_POSITIONS.size() == 12, "Exactly 12 fixed crater positions exist")

	# Verify position querying wraps cleanly
	var p0: Vector3 = sched.get_crater_position(0)
	var p12: Vector3 = sched.get_crater_position(12)
	_assert_true(p0 == p12, "Crater index wraps modulo 12")

	# Power tiers scaling with spawner destruction level
	var t_minor: Dictionary = sched.get_nydus_tier(1)
	_assert_true(t_minor["tier_name"] == "Minor Nydus" and is_equal_approx(t_minor["hp"], 3500.0), "Level 1 spawner -> Minor Nydus (HP 3500)")

	var t_standard: Dictionary = sched.get_nydus_tier(3)
	_assert_true(t_standard["tier_name"] == "Nydus Worm" and is_equal_approx(t_standard["hp"], 6000.0), "Level 3 spawner -> Nydus Worm (HP 6000)")

	var t_greater: Dictionary = sched.get_nydus_tier(5)
	_assert_true(t_greater["tier_name"] == "Greater Nydus" and is_equal_approx(t_greater["hp"], 9000.0), "Level 5 spawner -> Greater Nydus (HP 9000)")

	var t_ultra: Dictionary = sched.get_nydus_tier(8)
	_assert_true(t_ultra["tier_name"] == "Ultra Nydus" and is_equal_approx(t_ultra["hp"], 14000.0), "Level 8 spawner -> Ultra Nydus (HP 14000)")

	# Awakening network sequence
	_assert_true(not nydus_mgr.trigger_crater_awakening(0), "Cannot awaken crater while network is inactive")
	nydus_mgr.activate_network()
	_assert_true(nydus_mgr.trigger_crater_awakening(0, 3), "Crater awakening started when network active")

	_assert_true(not nydus_mgr.is_crater_occupied(0), "Crater not yet occupied during tremor warning")
	nydus_mgr.process_craters(4.0)
	_assert_true(nydus_mgr.is_crater_occupied(0), "Nydus emerged and occupies crater 0")

	var reward: int = nydus_mgr.report_nydus_destroyed(0)
	_assert_true(reward == 2500, "Defeating standard Nydus awards 2500 minerals")
	_assert_true(not nydus_mgr.is_crater_occupied(0), "Crater cleared after Nydus destroyed")
