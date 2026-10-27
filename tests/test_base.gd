class_name SFE_TestBase
extends RefCounted

## SFE_TestBase - Common testing framework for SFE5 unit, integration, and E2E tests.
## Provides structured assertions, failure diagnostics, and test state tracking.

static var runner_tree: SceneTree = null

var _last_error: String = ""
var _is_skipped: bool = false
var _skip_reason: String = ""

func pass_test() -> Dictionary:
	return {"passed": true}

func fail_test(message: String) -> Dictionary:
	_last_error = message
	return {"passed": false, "error": message}

func skip_test(reason: String) -> Dictionary:
	_is_skipped = true
	_skip_reason = reason
	return {"passed": true, "skipped": true, "reason": reason}

func get_last_failure() -> Dictionary:
	return {"passed": false, "error": _last_error}

func assert_true(cond: bool, msg: String = "Expected true, got false") -> bool:
	if not cond:
		_last_error = msg
		return false
	return true

func assert_false(cond: bool, msg: String = "Expected false, got true") -> bool:
	if cond:
		_last_error = msg
		return false
	return true

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		var detail := "Expected %s, but got %s" % [str(expected), str(actual)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_ne(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual == expected:
		var detail := "Expected value NOT equal to %s" % [str(expected)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> bool:
	var diff := absf(actual - expected)
	if diff > tolerance:
		var detail := "Expected %f ± %f, but got %f (diff: %f)" % [expected, tolerance, actual, diff]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_gt(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual > expected):
		var detail := "Expected %s > %s" % [str(actual), str(expected)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_ge(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual >= expected):
		var detail := "Expected %s >= %s" % [str(actual), str(expected)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_lt(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual < expected):
		var detail := "Expected %s < %s" % [str(actual), str(expected)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_le(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual <= expected):
		var detail := "Expected %s <= %s" % [str(actual), str(expected)]
		_last_error = detail if msg.is_empty() else "%s (%s)" % [msg, detail]
		return false
	return true

func assert_not_null(val: Variant, msg: String = "Expected non-null value") -> bool:
	if val == null:
		_last_error = msg
		return false
	return true

func assert_null(val: Variant, msg: String = "Expected null value") -> bool:
	if val != null:
		_last_error = "%s (got %s)" % [msg, str(val)]
		return false
	return true
