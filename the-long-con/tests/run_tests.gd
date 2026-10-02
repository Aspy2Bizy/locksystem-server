extends SceneTree
## Headless test runner.
##   godot --headless -s res://tests/run_tests.gd
## Exits 0 if every test passes, 1 otherwise (used by CI).
## Script errors raised while a test runs count as failures (Godot 4.5 Logger API).


class ErrorCounter:
	extends Logger
	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		pass


func _initialize() -> void:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var data := GameData.load_default()
	var total := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for file in files:
		counter.errors.clear()
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate() or not counter.errors.is_empty():
			total += 1
			failed += 1
			print("  FAIL %s (does not compile)" % file)
			continue
		for m in script.get_script_method_list():
			if not m.name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.data = data
			counter.errors.clear()
			var start := Time.get_ticks_msec()
			t.call(m.name)
			var ms := Time.get_ticks_msec() - start
			total += 1
			for e in counter.errors:
				t.failures.append("script error: " + e)
			if t.failures.is_empty():
				print("  PASS %s.%s (%d ms)" % [file.get_basename(), m.name, ms])
			else:
				failed += 1
				print("  FAIL %s.%s" % [file.get_basename(), m.name])
				for f in t.failures.slice(0, 10):
					print("       - " + f)
	OS.remove_logger(counter)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
