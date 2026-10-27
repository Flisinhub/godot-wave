extends SceneTree

## stress_p3_audio_polyphony_saturation.gd
## Adversarial stress harness for SFXManager and 7-Bus Audio Layout.
## Stress-tests:
## 1. Massive combat audio bombardment (hundreds of simultaneous weapon & bio sound requests).
## 2. Hard polyphony clamping enforcement (max 4 active voices per canonical sound ID).
## 3. Fixed pool limits (24 3D spatial players, 8 2D players, zero dynamic allocation churn).
## 4. AudioServer stability across 8 buses (Weapons, Explosions, Swarm, Voice, etc.).
## 5. Memory stability (zero node leakage, bounded static memory).

const SFXManagerScript = preload("res://core/audio/sfx_manager.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_reasons: Array[String] = []

func _init() -> void:
	print("\n================================================================================")
	print("=== EMPIRICAL CHALLENGER: AUDIO POLYPHONY CLAMPING & MEMORY STABILITY ===")
	print("================================================================================\n")
	
	_run_audio_stress()

func _assert(cond: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
		return true
	else:
		failed_tests += 1
		failure_reasons.append("%s: %s" % [test_name, error_msg])
		print("  \u001b[31m[FAIL]\u001b[0m %s: %s" % [test_name, error_msg])
		return false

func _run_audio_stress() -> void:
	# 1. Setup Audio Server & SFXManager
	print(">> [1/5] Verifying AudioServer 8-Bus Layout & Subsystem Integration...")
	var bus_layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	if bus_layout:
		AudioServer.set_bus_layout(bus_layout)
	
	var bus_count: int = AudioServer.get_bus_count()
	print("  * Total Audio Buses in AudioServer: %d" % bus_count)
	_assert(bus_count >= 8, "AudioServer has at least 8 buses", "Found %d buses" % bus_count)
	
	var expected_buses := ["Master", "Music", "Voice", "Ambience", "SFX", "Weapons", "Explosions", "Swarm"]
	for bname in expected_buses:
		var idx: int = AudioServer.get_bus_index(bname)
		_assert(idx >= 0, "AudioServer has bus '%s'" % bname, "Missing bus: %s" % bname)
	
	var sfx: Node = SFXManagerScript.new()
	sfx.name = "SFXManager"
	root.add_child(sfx)
	
	print("\n>> [2/5] Inspecting Fixed Pre-Allocated Audio Player Pools...")
	var p3_pool = sfx.get("pool_3d") as Array
	var p2_pool = sfx.get("pool_2d") as Array
	print("  * 3D Spatial Players in Pool: %d (Expected: 24)" % p3_pool.size())
	print("  * 2D Audio Players in Pool:   %d (Expected: 8)" % p2_pool.size())
	_assert(p3_pool.size() == 24, "3D Audio Player Pool exactly 24", "Got %d" % p3_pool.size())
	_assert(p2_pool.size() == 8, "2D Audio Player Pool exactly 8", "Got %d" % p2_pool.size())
	
	var test_sounds: Array[StringName] = [
		&"gauss_fire", &"snipe", &"cannon", &"shotgun", &"plasma", &"turret_fire",
		&"zergling_growl", &"roach_spit", &"hydra_spine", &"baneling_explode", &"zerg_death",
		&"base_under_attack", &"wave_incoming", &"hero_ack_1"
	]
	
	# Pre-cache all audio streams so we measure playback memory, not one-time file asset loads
	for snd in test_sounds:
		sfx.call("get_sound_stream", snd)
	
	# Initial baseline memory & node counts after stream caching
	var initial_nodes: int = root.get_child_count()
	var initial_mem: int = OS.get_static_memory_usage()
	
	# 2. Burst Saturation Stress Test (Single-Frame Clamping)
	print("\n>> [3/5] Stress Test: Rapid Burst Saturation (100 Simultaneous 'gauss_fire' Requests)...")
	var initial_dropped: int = sfx.get("dropped_plays")
	
	for i in range(100):
		sfx.call("play_sfx_3d", &"gauss_fire", Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), 4)
	
	var gauss_active: int = sfx.call("get_active_voice_count", &"gauss_fire")
	var post_dropped: int = sfx.get("dropped_plays")
	var dropped_delta: int = post_dropped - initial_dropped
	
	print("  * Active Voices for 'gauss_fire': %d (Clamped Max: 4)" % gauss_active)
	print("  * Dropped Requests in Burst:      %d / 100" % dropped_delta)
	
	_assert(gauss_active <= 4, "Polyphony clamp: 'gauss_fire' active voices <= 4", "Got %d active voices" % gauss_active)
	_assert(dropped_delta >= 96, "Dropped plays correctly increments for clamped sounds (>= 96 dropped)", "Only dropped %d" % dropped_delta)
	
	# 3. Mass Combat Multi-Strain & Weapon Audio Saturation across 60 frames
	print("\n>> [4/5] Stress Test: Mass Multi-Sound Combat Simulation (1,200 Sound Requests across 60 frames)...")
	var polyphony_violations: int = 0
	var pool_overflow_violations_3d: int = 0
	var total_requests_sent: int = 0
	
	for frame in range(60):
		# Each frame, fire 20 sounds randomly from weapons and swarm
		for burst in range(20):
			var snd: StringName = test_sounds[randi() % test_sounds.size()]
			var pos := Vector3(randf_range(-25.0, 25.0), 0.0, randf_range(-25.0, 25.0))
			sfx.call("play_sfx_3d", snd, pos, 4)
			total_requests_sent += 1
		
		# Inspect all test sounds for polyphony violation
		for snd in test_sounds:
			var active: int = sfx.call("get_active_voice_count", snd)
			if active > 4:
				polyphony_violations += 1
		
		# Count total active 3D players in pool
		var active_3d_count: int = 0
		for idx in range(p3_pool.size()):
			if sfx.call("_is_player_3d_active", idx):
				active_3d_count += 1
		if active_3d_count > 24:
			pool_overflow_violations_3d += 1
	
	var final_dropped: int = sfx.get("dropped_plays")
	var final_total_plays: int = sfx.get("total_plays")
	
	print("  * Total Sound Playback Requests Sent:  %d" % total_requests_sent)
	print("  * Total Successfully Routed Plays:     %d" % final_total_plays)
	print("  * Total Polyphony Clamped/Dropped:     %d" % final_dropped)
	print("  * Polyphony Violations (> 4 per ID):   %d" % polyphony_violations)
	print("  * 3D Pool Overflow Violations (> 24):  %d" % pool_overflow_violations_3d)
	
	_assert(polyphony_violations == 0, "Zero polyphony violations (> 4 per ID) across 1,200 combat sounds", "Detected %d violations" % polyphony_violations)
	_assert(pool_overflow_violations_3d == 0, "Zero 3D pool overflows (> 24 active players)", "Detected %d overflows" % pool_overflow_violations_3d)
	_assert(final_total_plays > 0, "SFX successfully routed to available pooled players", "Zero successful plays")
	
	# 4. Memory Stability & Leak Detection
	print("\n>> [5/5] Audio Subsystem Memory Stability & Leak Verification...")
	var final_nodes: int = root.get_child_count()
	var final_mem: int = OS.get_static_memory_usage()
	var mem_delta_kb: float = float(final_mem - initial_mem) / 1024.0
	var node_delta: int = final_nodes - initial_nodes
	
	print("  * Initial Root Child Nodes: %d -> Final Root Child Nodes: %d (Delta: %d)" % [initial_nodes, final_nodes, node_delta])
	print("  * Static Memory Delta after 1,300 Audio Calls: %.2f KB" % mem_delta_kb)
	
	_assert(node_delta == 0, "Zero leaked AudioStreamPlayer nodes in SceneTree", "Node count increased by %d" % node_delta)
	_assert(mem_delta_kb < 128.0, "Audio static memory bounded (< 128 KB)", "Memory grew by %.2f KB" % mem_delta_kb)
	
	# Clean up SFX node
	sfx.free()
	
	print("\n================================================================================")
	print("AUDIO POLYPHONY & STABILITY SUMMARY:")
	print("Total Invariants Tested: %d" % total_tests)
	print("Passed:                  %d" % passed_tests)
	print("Failed:                  %d" % failed_tests)
	
	if failed_tests > 0:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] AUDIO INVARIANTS FAILED:\u001b[0m")
		for r in failure_reasons:
			print("  - %s" % r)
		print("================================================================================")
		quit(1)
	else:
		print("\u001b[32m[VERDICT: APPROVE] ALL AUDIO POLYPHONY INVARIANTS SATISFIED!\u001b[0m")
		print("================================================================================")
		quit(0)
