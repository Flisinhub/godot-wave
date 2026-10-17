class_name BankManager
extends RefCounted

## BankManager - Atomic 3-Stage Persistence Engine with SHA-256 Checksum Validation.
## Implements crash & tamper resilience via strict file rotation:
## RAM -> user://sfe5_bank.tmp -> verify SHA-256 -> rotate .save to .bak -> rotate .tmp to .save.
## Windows-safe atomic rename (explicit destination unlink prior to rename).

const SAVE_PATH: String = "user://sfe5_bank.save"
const BAK_PATH: String = "user://sfe5_bank.bak"
const TMP_PATH: String = "user://sfe5_bank.tmp"
const MAGIC_HEADER: String = "SFE5_BANK_V1"
const CURRENT_VERSION: int = 1


static func save_bank(payload: Dictionary) -> bool:
	var canonical_payload: Dictionary = _canonicalize(payload) as Dictionary
	var payload_json: String = JSON.stringify(canonical_payload)
	var checksum: String = payload_json.sha256_text()

	var envelope: Dictionary = {
		"magic": MAGIC_HEADER,
		"version": CURRENT_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"checksum": checksum,
		"payload": canonical_payload
	}
	var full_json: String = JSON.stringify(envelope, "\t")

	# Step 1: Write to .tmp with explicit flush
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)

	var tmp_file: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if not tmp_file:
		push_error("BankManager: Failed to open temp file for write: " + TMP_PATH)
		return false

	tmp_file.store_string(full_json)
	tmp_file.flush()
	tmp_file.close()

	# Step 2: Verification of .tmp prior to committing rotation
	if not _verify_bank_file(TMP_PATH):
		push_error("BankManager: Temp file verification failed. Aborting rotation.")
		if FileAccess.file_exists(TMP_PATH):
			DirAccess.remove_absolute(TMP_PATH)
		return false

	# Step 3: Windows-safe atomic file rotation
	# 3a. Rotate current .save to .bak
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BAK_PATH):
			DirAccess.remove_absolute(BAK_PATH)
		var err_bak: Error = DirAccess.rename_absolute(SAVE_PATH, BAK_PATH)
		if err_bak != OK:
			push_error("BankManager: Failed to rotate .save to .bak. Error code: " + str(err_bak))
			return false

	# 3b. Rotate .tmp to .save
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var err_save: Error = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err_save != OK:
		push_error("BankManager: Failed to rename .tmp to .save. Error code: " + str(err_save))
		# Attempt rollback from .bak
		if FileAccess.file_exists(BAK_PATH):
			DirAccess.rename_absolute(BAK_PATH, SAVE_PATH)
		return false

	# 3c. Ensure .bak always holds a verified copy of this save for single-save crash/tamper fallback
	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(BAK_PATH)
	DirAccess.copy_absolute(SAVE_PATH, BAK_PATH)

	return true


static func load_bank() -> Dictionary:
	# Primary attempt: .save
	if FileAccess.file_exists(SAVE_PATH):
		var data: Dictionary = _read_and_verify(SAVE_PATH)
		if not data.is_empty():
			return data
		push_warning("BankManager: Primary .save corrupt, empty, or checksum mismatch. Attempting .bak fallback.")

	# Secondary fallback: .bak
	if FileAccess.file_exists(BAK_PATH):
		var data_bak: Dictionary = _read_and_verify(BAK_PATH)
		if not data_bak.is_empty():
			# Restore primary from backup
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)
			DirAccess.copy_absolute(BAK_PATH, SAVE_PATH)
			return data_bak
		push_error("BankManager: Backup .bak corrupt or invalid.")

	# Tertiary: Initial blank/default state
	push_warning("BankManager: No valid save found. Generating default bank.")
	var default_bank: Dictionary = _create_default_bank()
	save_bank(default_bank)
	return default_bank


static func _verify_bank_file(path: String) -> bool:
	var data: Dictionary = _read_and_verify(path)
	return not data.is_empty()


static func _read_and_verify(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text: String = file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		return {}

	var json_res: Variant = JSON.parse_string(text)
	if not (json_res is Dictionary):
		return {}

	var env: Dictionary = json_res as Dictionary
	if env.get("magic") != MAGIC_HEADER:
		return {}

	var raw_payload: Variant = env.get("payload")
	if not (raw_payload is Dictionary):
		return {}

	var canonical_payload: Dictionary = _canonicalize(raw_payload) as Dictionary
	var expected_checksum: String = str(env.get("checksum", ""))
	var payload_json: String = JSON.stringify(canonical_payload)
	var computed_checksum: String = payload_json.sha256_text()

	if computed_checksum != expected_checksum:
		push_error("BankManager: Checksum mismatch in " + path)
		return {}

	return canonical_payload


static func _canonicalize(v: Variant) -> Variant:
	if typeof(v) == TYPE_FLOAT:
		var f: float = v as float
		if not is_nan(f) and not is_inf(f) and floor(f) == f:
			return int(f)
		return f
	elif typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = {}
		var dict: Dictionary = v as Dictionary
		var keys: Array = dict.keys()
		keys.sort()
		for k in keys:
			d[k] = _canonicalize(dict[k])
		return d
	elif typeof(v) == TYPE_ARRAY:
		var arr: Array = []
		for elem in (v as Array):
			arr.append(_canonicalize(elem))
		return arr
	return v


static func _create_default_bank() -> Dictionary:
	return {
		"account_id": "recruit_" + str(randi() % 99999),
		"veterancy_level": 1,
		"total_kills": 0,
		"bosses_defeated": [],
		"unlocked_heroes": ["marine"],
		"achievements": {},
		"settings": {
			"smart_cast": true,
			"camera_pan_speed": 15.0
		}
	}
