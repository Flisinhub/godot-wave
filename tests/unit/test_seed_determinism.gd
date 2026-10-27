extends RefCounted

## Unit tests for MapSeed determinism and CLI seed parsing (R1 Paso 1.2).

const MapSeed = preload("res://core/map/map_seed.gd")
const MapGenerator = preload("res://core/map/map_generator.gd")
const GameSession = preload("res://core/game_session.gd")


func test_cli_seed_parser_fallback() -> Dictionary:
	# In test runner headless mode, unless --seed was passed to Godot, it defaults to 0.
	var cli_val: int = GameSession.parse_cli_seed()
	if cli_val < 0:
		return {"passed": false, "error": "CLI seed should not be negative"}
	return {"passed": true}


func test_identical_seed_yields_identical_layout() -> Dictionary:
	var seed_val: int = 54321
	var gen_a := MapGenerator.new(MapSeed.new(seed_val))
	var gen_b := MapGenerator.new(MapSeed.new(seed_val))

	var plan_a := gen_a.generate_layout_plan(3)
	var plan_b := gen_b.generate_layout_plan(3)

	if plan_a.size() != 3 or plan_b.size() != 3:
		return {"passed": false, "error": "Expected 3 spawners in both layout plans"}

	for i in range(3):
		var sp_a: Dictionary = plan_a[i]
		var sp_b: Dictionary = plan_b[i]

		if sp_a["id"] != sp_b["id"]:
			return {"passed": false, "error": "Spawner id mismatch at index %d" % i}
		
		var pos_a: Vector3 = sp_a["position"]
		var pos_b: Vector3 = sp_b["position"]
		if not pos_a.is_equal_approx(pos_b):
			return {"passed": false, "error": "Position mismatch at %d: %s vs %s" % [i, str(pos_a), str(pos_b)]}
		
		if sp_a["family_id"] != sp_b["family_id"]:
			return {"passed": false, "error": "Family mismatch at %d: %s vs %s" % [i, sp_a["family_id"], sp_b["family_id"]]}

	var sig_a := gen_a.get_layout_signature(plan_a)
	var sig_b := gen_b.get_layout_signature(plan_b)
	if sig_a != sig_b:
		return {"passed": false, "error": "Signature mismatch: %s vs %s" % [sig_a, sig_b]}

	return {"passed": true}


func test_distinct_seeds_yield_distinct_layouts() -> Dictionary:
	var distinct_count: int = 0
	var test_pairs: int = 10

	for i in range(test_pairs):
		var seed_1: int = 1000 + i * 97
		var seed_2: int = 9000 + i * 113

		var gen_1 := MapGenerator.new(MapSeed.new(seed_1))
		var gen_2 := MapGenerator.new(MapSeed.new(seed_2))

		var plan_1 := gen_1.generate_layout_plan(3)
		var plan_2 := gen_2.generate_layout_plan(3)

		var identical := true
		for j in range(3):
			var pos_1: Vector3 = plan_1[j]["position"]
			var pos_2: Vector3 = plan_2[j]["position"]
			if not pos_1.is_equal_approx(pos_2):
				identical = false
				break
		
		if not identical:
			distinct_count += 1

	if distinct_count != test_pairs:
		return {"passed": false, "error": "Expected all %d pairs to produce distinct layouts, got %d" % [test_pairs, distinct_count]}

	return {"passed": true}
