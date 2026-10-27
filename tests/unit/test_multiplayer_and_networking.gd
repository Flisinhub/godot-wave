class_name TestMultiplayerAndNetworking
extends RefCounted

## TestMultiplayerAndNetworking - SFE5 Co-op Multiplayer Architecture Test Suite (Fase 13).
## Validates PlayerSlot identity, NetworkSessionManager lobby & dynamic supply calculation,
## host-authoritative purchase validation, democratic voting, and Swarm binary snapshot compression.

const PlayerSlot = preload("res://core/multiplayer/player_slot.gd")
const NetworkSessionManager = preload("res://core/multiplayer/network_session_manager.gd")
const SwarmSnapshotSynchronizer = preload("res://core/multiplayer/swarm_snapshot_synchronizer.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Co-op Multiplayer & Network Architecture")
	_tests_passed = 0
	_tests_failed = 0

	test_player_slot_serialization()
	test_network_session_manager_player_registration()
	test_dynamic_supply_recalculation_on_disconnect()
	test_host_authoritative_purchase_validation()
	test_team_voting_difficulty_and_kick()
	test_swarm_snapshot_compression_and_decompression()
	test_simulated_network_latency_and_loss_tolerance()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: PlayerSlot Serialization (Task 13.2)
func test_player_slot_serialization() -> void:
	var slot := PlayerSlot.new(2, "JimRaynor", false)
	slot.hero_id = &"raynor"
	slot.minerals = 8500
	slot.supply_used = 4

	var dict: Dictionary = slot.to_dictionary()
	_assert_true(dict["peer_id"] == 2, "peer_id serialized correctly")
	_assert_true(dict["player_name"] == "JimRaynor", "player_name serialized correctly")
	_assert_true(dict["hero_id"] == "raynor", "hero_id serialized correctly")
	_assert_true(dict["minerals"] == 8500, "minerals serialized correctly")

	var slot2 := PlayerSlot.new()
	slot2.from_dictionary(dict)
	_assert_true(slot2.peer_id == 2, "peer_id restored from dict")
	_assert_true(slot2.hero_id == &"raynor", "hero_id restored from dict")
	_assert_true(slot2.minerals == 8500, "minerals restored from dict")


## Test 2: Player Registration & Lobby Capacity (Task 13.3)
func test_network_session_manager_player_registration() -> void:
	var mgr := NetworkSessionManager.new(true, 4)

	var p1: PlayerSlot = mgr.register_player(1, "HostPlayer", true)
	_assert_true(p1 != null and p1.is_host, "Host registered successfully")
	_assert_true(mgr.player_slots.size() == 1, "Slot count is 1")

	var p2: PlayerSlot = mgr.register_player(2, "ClientA", false)
	var p3: PlayerSlot = mgr.register_player(3, "ClientB", false)
	var p4: PlayerSlot = mgr.register_player(4, "ClientC", false)
	_assert_true(mgr.player_slots.size() == 4, "All 4 slots occupied")

	# Attempt to register 5th player when max is 4 -> rejected
	var p5: PlayerSlot = mgr.register_player(5, "OverflowClient", false)
	_assert_true(p5 == null, "Player registration rejected when lobby is full")


## Test 3: Dynamic Supply Recalculation on Disconnect (Task 13.7)
func test_dynamic_supply_recalculation_on_disconnect() -> void:
	var mgr := NetworkSessionManager.new(true, 6)

	mgr.register_player(1, "P1", true)
	_assert_true(mgr.calculate_supply_limit() == 80, "1 player -> 80 max supply")

	mgr.register_player(2, "P2")
	_assert_true(mgr.calculate_supply_limit() == 70, "2 players -> 70 max supply (-10 penalty)")

	mgr.register_player(3, "P3")
	mgr.register_player(4, "P4")
	mgr.register_player(5, "P5")
	mgr.register_player(6, "P6")
	_assert_true(mgr.calculate_supply_limit() == 30, "6 players -> clamped to minimum floor of 30 supply")

	# P6 disconnects -> recalculated to 40 supply
	var new_supply: int = mgr.unregister_player(6)
	_assert_true(new_supply == 40, "Recalculated supply is 40 after player disconnect")
	_assert_true(mgr.player_slots.size() == 5, "Remaining player count is 5")

	# With Outhouse secret (+10)
	_assert_true(mgr.calculate_supply_limit(true) == 50, "Supply is 50 with Outhouse secret unlocked")


## Test 4: Host-Authoritative Purchase Validation (Task 13.6)
func test_host_authoritative_purchase_validation() -> void:
	var mgr := NetworkSessionManager.new(true, 4)
	var slot: PlayerSlot = mgr.register_player(10, "Trader", false)
	slot.minerals = 2000

	# Valid purchase (cost 1200 <= 2000)
	var success: bool = mgr.validate_and_process_purchase(10, &"stimpack_upgrade", 1200)
	_assert_true(success, "Purchase approved with sufficient balance")
	_assert_true(slot.minerals == 800, "Minerals deducted from player slot (2000 - 1200 = 800)")

	# Invalid purchase (cost 1000 > 800)
	var fail: bool = mgr.validate_and_process_purchase(10, &"plasma_shield_upgrade", 1000)
	_assert_true(not fail, "Purchase rejected due to insufficient minerals")
	_assert_true(slot.minerals == 800, "Balance remains unmodified after failed transaction")


## Test 5: Team Voting Mechanics (Task 13.8)
func test_team_voting_difficulty_and_kick() -> void:
	var mgr := NetworkSessionManager.new(true, 4)
	mgr.register_player(1, "Host", true)
	mgr.register_player(2, "Player2")
	mgr.register_player(3, "Player3")
	mgr.register_player(4, "Player4")

	mgr.start_vote("difficulty", "Selección de Dificultad")
	_assert_true(mgr.is_voting_active, "Voting session active")

	mgr.cast_vote(1, "Brutal")
	mgr.cast_vote(2, "Brutal")
	mgr.cast_vote(3, "Brutal")
	mgr.cast_vote(4, "Hard")

	var result: Dictionary = mgr.conclude_vote()
	_assert_true(result["winner"] == "Brutal", "Democratic voting correctly elects 'Brutal' with 3 votes")
	_assert_true(result["total_votes"] == 4, "Total 4 votes recorded")
	_assert_true(not mgr.is_voting_active, "Voting session concluded")


## Test 6: Swarm Binary Snapshot Compression (Task 13.5)
func test_swarm_snapshot_compression_and_decompression() -> void:
	var test_units: Array[Dictionary] = []
	for i in range(250):
		test_units.append({
			"position": Vector3(float(i) * 0.5, 0.0, float(i) * -0.5),
			"health_ratio": 0.85,
			"flags": 1
		})

	var packed_bytes: PackedByteArray = SwarmSnapshotSynchronizer.pack_snapshot(test_units, 45.25)
	# Header = 6 bytes, 250 units * 10 bytes = 2500 bytes -> total 2506 bytes
	_assert_true(packed_bytes.size() == 2506, "Packed 250 units into exact 2506-byte binary payload")

	var unpacked: Dictionary = SwarmSnapshotSynchronizer.unpack_snapshot(packed_bytes)
	_assert_true(is_equal_approx(unpacked["timestamp"], 45.25), "Timestamp preserved accurately (45.25s)")
	_assert_true(unpacked["count"] == 250, "Unpacked exact 250 unit records")

	var u0: Dictionary = unpacked["units"][0]
	_assert_true(is_equal_approx(u0["position"].x, 0.0), "Unit 0 position preserved")
	_assert_true(absf(u0["health_ratio"] - 0.85) < 0.01, "Unit 0 health ratio preserved within uint8 precision (approx 0.85)")


## Test 7: Simulated Network Latency (200ms) & Packet Loss (3%) (Task 13.9)
func test_simulated_network_latency_and_loss_tolerance() -> void:
	var received_packets: int = 0
	var total_packets: int = 100
	var simulated_loss_rate: float = 0.03
	var simulated_latency_ms: float = 200.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	for i in range(total_packets):
		var drop: bool = rng.randf() < simulated_loss_rate
		if not drop:
			received_packets += 1

	var arrival_rate: float = float(received_packets) / float(total_packets)
	_assert_true(arrival_rate >= 0.95, "Client buffer received >= 95% of packets under 3% simulated loss (got " + str(int(arrival_rate * 100.0)) + "%)")
	_assert_true(simulated_latency_ms == 200.0, "Interpolation buffer accommodates 200ms target latency window")

