extends SceneTree
## Print a generated bank as text.
##   godot --headless -s res://tools/dump_bank.gd -- <seed> [stars]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var bank_seed := int(args[0]) if args.size() > 0 else 12345
	var stars := int(args[1]) if args.size() > 1 else 3
	var data := GameData.load_default()
	var gen := BankGenerator.new(data)
	var bank := gen.generate(bank_seed, stars)
	if bank.is_empty():
		print("FAILED:\n" + "\n".join(gen.last_errors))
		quit(1)
		return
	print(BankDebug.ascii(bank))
	quit(0)
