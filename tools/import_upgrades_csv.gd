@tool
extends SceneTree

## Standalone / Editor Tool for importing CSV upgrades into UpgradeData .tres resources (Task 2.9).
## Usage:
##   godot --headless --path . -s tools/import_upgrades_csv.gd [csv_path] [output_dir]

const UpgradeDataScript = preload("res://core/data/upgrade_data.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var csv_path: String = "res://data/upgrades/sample_upgrades.csv"
	var out_dir: String = "res://data/upgrades"

	if args.size() >= 1:
		csv_path = args[0]
	if args.size() >= 2:
		out_dir = args[1]

	print("[CSV UPGRADES IMPORTER] Reading from: %s" % csv_path)
	var count := import_csv(csv_path, out_dir)
	print("[CSV UPGRADES IMPORTER] Successfully imported %d upgrades into %s" % [count, out_dir])
	quit(0)


static func import_csv(csv_path: String, out_dir: String) -> int:
	if not FileAccess.file_exists(csv_path):
		printerr("CSV file not found: %s" % csv_path)
		return 0

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		printerr("Failed to open CSV file: %s" % csv_path)
		return 0

	var header_line := file.get_line()
	var headers := header_line.split(",")
	var imported_count := 0

	var da := DirAccess.open("res://")
	if not da.dir_exists(out_dir):
		da.make_dir_recursive(out_dir)

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var cols := line.split(",")
		if cols.size() < 9:
			continue

		var up = UpgradeDataScript.new()
		up.id = StringName(cols[0].strip_edges())
		up.upgrade_name = cols[1].strip_edges()
		up.category = cols[2].strip_edges()
		up.race = cols[3].strip_edges()
		up.max_level = int(cols[4].strip_edges())
		up.base_cost = int(cols[5].strip_edges())
		up.cost_growth_multiplier = float(cols[6].strip_edges())
		up.flat_effect_per_level = float(cols[7].strip_edges())
		up.multiplier_effect_per_level = float(cols[8].strip_edges())
		if cols.size() >= 10:
			up.description = cols[9].strip_edges()

		var file_path := out_dir.path_join("%s.tres" % str(up.id))
		var err := ResourceSaver.save(up, file_path)
		if err == OK:
			imported_count += 1
		else:
			printerr("Failed to save resource %s: %d" % [file_path, err])

	file.close()
	return imported_count
