class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/run_tests.gd.

var failures: PackedStringArray = []
var data: GameData


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])
