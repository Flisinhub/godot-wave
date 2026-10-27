extends SceneTree

const IncomeParams = preload("res://core/economy/income_params.gd")
const IncomeFormula = preload("res://core/economy/income_formula.gd")

func _init() -> void:
	var cases: Array = [
		{"name": "Standard Zergling (Solo, Normal)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Zergling (Casual x1.15)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.15},
		{"name": "Zergling (Hard x0.80)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 0.80},
		{"name": "Zergling (Brutal x0.70)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 0.70},
		{"name": "Zergling (Torment x0.60)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 0.60},
		{"name": "Zergling (Impossible x0.30)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 0.30},
		{"name": "Standard Roach (Solo, Normal)", "hp": 145.0, "sh": 0.0, "dmg": 16.0, "period": 2.0, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Standard Hydralisk (Solo, Normal)", "hp": 80.0, "sh": 0.0, "dmg": 12.0, "period": 0.83, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Ultralisk Colossus", "hp": 500.0, "sh": 0.0, "dmg": 35.0, "period": 0.86, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Unarmed Larva / Drone", "hp": 40.0, "sh": 0.0, "dmg": 0.0, "period": 1.0, "weapon": false, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Caster Unit with Energy (Defiler 200 energy)", "hp": 80.0, "sh": 0.0, "dmg": 0.0, "period": 1.0, "weapon": false, "energy": 200.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Protoss Zealot with Shield", "hp": 100.0, "sh": 50.0, "dmg": 16.0, "period": 1.2, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Zerg Spawner Structure (x8.0 category)", "hp": 1500.0, "sh": 0.0, "dmg": 0.0, "period": 1.0, "weapon": false, "energy": 0.0, "cat": "structure", "cat_mult": 8.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Heroic Boss Entity (x4.0 category)", "hp": 800.0, "sh": 200.0, "dmg": 45.0, "period": 0.8, "weapon": true, "energy": 150.0, "cat": "heroic", "cat_mult": 4.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Elite Map Boss (x6.0 category)", "hp": 3000.0, "sh": 0.0, "dmg": 60.0, "period": 1.0, "weapon": true, "energy": 0.0, "cat": "elite", "cat_mult": 6.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Summoned Boss (x2.0 category)", "hp": 4000.0, "sh": 500.0, "dmg": 80.0, "period": 1.0, "weapon": true, "energy": 0.0, "cat": "summoned_boss", "cat_mult": 2.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Pinnacle Boss (x6.0 category)", "hp": 15000.0, "sh": 5000.0, "dmg": 150.0, "period": 0.75, "weapon": true, "energy": 200.0, "cat": "pinnacle_boss", "cat_mult": 6.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Mega Overpowered Boss (s > 500,000 threshold)", "hp": 2000000.0, "sh": 500000.0, "dmg": 10000.0, "period": 0.5, "weapon": true, "energy": 0.0, "cat": "pinnacle_boss", "cat_mult": 6.0, "players": 1, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Split Income Mode (Zergling)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 4, "split": true, "pedestal": 0.0, "diff": 1.0},
		{"name": "Shared Income with 2 Players", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 2, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Shared Income with 4 Players", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 4, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Shared Income with 6 Players", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 6, "split": false, "pedestal": 0.0, "diff": 1.0},
		{"name": "Pedestal Puzzle Active (+5 flat bonus)", "hp": 35.0, "sh": 0.0, "dmg": 5.0, "period": 0.7, "weapon": true, "energy": 0.0, "cat": "normal", "cat_mult": 1.0, "players": 1, "split": false, "pedestal": 5.0, "diff": 1.0}
	]

	var output_cases: Array = []
	for c in cases:
		var p = IncomeParams.new()
		p.base_health = c["hp"]
		p.base_shield = c["sh"]
		p.weapon_damage = c["dmg"]
		p.attack_period = c["period"]
		p.has_weapon = c["weapon"]
		p.max_energy = c["energy"]
		p.category = c["cat"]
		p.category_multiplier = c["cat_mult"]
		p.player_count = c["players"]
		p.split_income = c["split"]
		p.pedestal_bonus = c["pedestal"]
		p.difficulty_mult = c["diff"]
		var reward: int = IncomeFormula.compute(p)
		c["expected_minerals"] = reward
		output_cases.append(c)

	var json_str = JSON.stringify(output_cases, "\t")
	var fa = FileAccess.open("res://tests/unit/income_reference_cases.json", FileAccess.WRITE)
	fa.store_string(json_str)
	fa.close()
	print("Saved %d reference cases." % output_cases.size())
	quit(0)
