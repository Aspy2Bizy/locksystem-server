extends TestCase
## Bank generator: every seed must produce a valid, deterministic bank.

const SEEDS := 60


func test_many_seeds_all_tiers_valid() -> void:
	var gen := BankGenerator.new(data)
	var attempts_total := 0
	for stars in range(1, 7):
		for i in SEEDS:
			var s := 1000 + i * 7919 + stars
			var bank := gen.generate(s, stars)
			check(not bank.is_empty(), "seed %d stars %d failed: %s" % [s, stars, gen.last_errors.slice(-1)])
			if not bank.is_empty():
				attempts_total += bank.attempt + 1
				check(BankValidator.validate(bank, data).is_empty(), "seed %d revalidation" % s)
	var avg := float(attempts_total) / (SEEDS * 6)
	print("       avg attempts per bank: %.2f" % avg)
	check(avg < 6.0, "generator needs too many attempts on average (%.2f)" % avg)


func test_deterministic() -> void:
	var a := BankGenerator.new(data).generate(424242, 4)
	var b := BankGenerator.new(data).generate(424242, 4)
	check_eq(JSON.stringify(BankDebug.to_json_safe(a)), JSON.stringify(BankDebug.to_json_safe(b)), "same seed, same bank")
	var c := BankGenerator.new(data).generate(424243, 4)
	check(JSON.stringify(BankDebug.to_json_safe(a)) != JSON.stringify(BankDebug.to_json_safe(c)), "different seed, different bank")


func test_vertical_alignment_and_shape() -> void:
	var bank := BankGenerator.new(data).generate(777, 3)
	var stair_cells := {}
	for f in bank.floors:
		var stair: Dictionary = bank.rooms[f.rooms[1]]
		check_eq(stair.id, "stairwell", "room slot 1 is the stairwell")
		stair_cells[stair.cells[0]] = true
	check_eq(stair_cells.size(), 1, "stairs line up on every floor")
	check_eq(bank.floors[0].type, "parking", "bottom floor")
	check_eq(bank.floors[-1].type, "roof", "top floor")
	var lobby: Array = bank.floors.filter(func(f): return f.type == "lobby")
	check_eq(lobby.size(), 1, "one lobby")
	check_eq(lobby[0].level, 0, "lobby is ground level")


func test_vault_rules() -> void:
	var gen := BankGenerator.new(data)
	for i in 30:
		var bank := gen.generate(5000 + i, 3)
		var vault: Dictionary = bank.rooms[bank.vault.room]
		check_eq(vault.doors.size(), 1, "vault has exactly one door")
		var d: Dictionary = bank.doors[vault.doors[0]]
		var other: int = d.b if d.a == vault.idx else d.a
		check_eq(bank.rooms[other].id, "vault_antechamber", "vault door opens into antechamber")
		check_eq(d.lock, "vault", "vault door uses the vault lock")
		for c in vault.cells:
			check(c.x > 0 and c.y > 0 and c.x < bank.w - 1 and c.y < bank.h - 1, "vault not on outer wall")


func test_contents() -> void:
	var bank := BankGenerator.new(data).generate(31337, 5)
	check(bank.civilians.any(func(c): return c.type == "manager"), "manager spawned")
	check(bank.civilians.any(func(c): return c.type == "security_chief"), "security chief spawned")
	check_eq(bank.civilians.filter(func(c): return c.type == "guard").size(), bank.security.guards, "guard count")
	check(bank.security.cameras.size() >= 4, "minimum cameras")
	check(bank.escape_routes.size() >= 2, "at least two escape routes")


func test_harder_vault_means_softer_security() -> void:
	# Over many seeds at one tier, expensive vaults should average fewer cameras.
	var gen := BankGenerator.new(data)
	var cheap := []
	var pricey := []
	for i in 80:
		var bank := gen.generate(9000 + i, 5)
		var cost: int = data.vault_hazards[bank.vault.hazard].budget_cost + data.vault_locks[bank.vault.lock].budget_cost
		(pricey if cost >= 55 else cheap).append(bank.security.cameras.size())
	if cheap.is_empty() or pricey.is_empty():
		return
	var avg := func(a): return a.reduce(func(x, y): return x + y, 0) / float(a.size())
	check(avg.call(pricey) <= avg.call(cheap), "pricey vaults average <= cameras (%.1f vs %.1f)" % [avg.call(pricey), avg.call(cheap)])


func test_scouting_reveals_less_when_harder() -> void:
	var gen := BankGenerator.new(data)
	var easy := 0
	var hard := 0
	for i in 20:
		var b1 := gen.generate(100 + i, 1)
		easy += Scouting.reveal(b1, data, 1).known_rooms.size() * 100 / b1.rooms.size()
		var b6 := gen.generate(100 + i, 6)
		hard += Scouting.reveal(b6, data, 1).known_rooms.size() * 100 / b6.rooms.size()
	check(hard < easy, "6 stars reveals less than 1 star (%d vs %d)" % [hard, easy])
