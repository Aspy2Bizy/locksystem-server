class_name BankContents
extends RefCounted
## Fills a laid-out bank: vault modules, security (cameras, guards, door locks),
## civilians and available escape routes. Uses the generator's rng so it stays seed-stable.


static func populate(bank: Dictionary, data: GameData, rng: RandomNumberGenerator) -> void:
	var tier := data.tier(bank.stars)
	var vm: Dictionary = data.raw.vault_modules
	var costs: Dictionary = vm.security_costs
	var budget := int(tier.security_budget)

	# Vault: hazard first, then a lock that fits the remaining budget.
	var hazard := _pick(rng, vm.hazards)
	var min_security := int(costs.min_cameras) * int(costs.camera_cost) + int(costs.min_guards) * int(costs.guard_cost)
	var room_left := budget - int(hazard.budget_cost) - min_security
	var locks: Array = vm.locks.filter(func(l): return int(l.budget_cost) <= room_left)
	if locks.is_empty():
		locks = [vm.locks.reduce(func(a, b): return a if a.budget_cost <= b.budget_cost else b)]
	var lock := _pick(rng, locks)
	var deps: Array = vm.staff_dependencies.filter(func(s): return VaultSolver.requirements_met(s.requires, bank, data))
	var vault_room := _first_room(bank, "vault")
	bank.vault = {
		"room": vault_room,
		"layout": _pick(rng, vm.layouts).id,
		"lock": lock.id,
		"lock_family": lock.family,
		"hazard": hazard.id,
		"staff_dependency": _pick(rng, deps).id,
		"lock_solutions": VaultSolver.feasible(lock.solutions, bank, data),
		"hazard_solutions": VaultSolver.feasible(hazard.solutions, bank, data),
	}

	# Security budget left after the vault buys cameras and guards (hard vault = softer floors).
	var spend := maxi(0, budget - int(hazard.budget_cost) - int(lock.budget_cost))
	var cameras := maxi(int(costs.min_cameras), int(spend * 0.5) / int(costs.camera_cost))
	var guards := maxi(int(costs.min_guards), int(spend * 0.5) / int(costs.guard_cost))
	var cfg := data.seed_config()
	guards = clampi(guards, int(cfg.security.guards_total[0]), int(cfg.security.guards_total[1]))

	var cam_rooms: Array = bank.rooms.filter(func(r):
		return r.kind != "filler" and BankGenerator._shares(r.tags, ["public", "secure", "route", "cash_small", "cash_medium", "lobby"]))
	var cams: Array = []
	for i in cameras:
		if cam_rooms.is_empty():
			break
		var r: Dictionary = cam_rooms[rng.randi_range(0, cam_rooms.size() - 1)]
		var c: Vector2i = r.cells[rng.randi_range(0, r.cells.size() - 1)]
		cams.append({"room": r.idx, "floor": r.floor, "cell": [c.x, c.y], "yaw_deg": rng.randi_range(0, 3) * 90})
	bank.security = {"cameras": cams, "guards": guards}

	# Door locks
	var lock_types: Array = cfg.security.lock_types.filter(func(t): return t != "none")
	for d in bank.doors:
		if d.b == BankGenerator.EXTERIOR:
			continue
		var ra: Dictionary = bank.rooms[d.a]
		var rb: Dictionary = bank.rooms[d.b]
		if ra.id == "vault" or rb.id == "vault":
			d.lock = "vault"
		elif ("staff_only" in ra.tags or "staff_only" in rb.tags or "secure" in ra.tags or "secure" in rb.tags) \
				and rng.randf() < float(cfg.security.staff_only_lock_chance):
			d.lock = lock_types[rng.randi_range(0, lock_types.size() - 1)]

	# Civilians
	var civ: Dictionary = data.raw.civilians
	var civs: Array = []
	var count := rng.randi_range(int(cfg.civilians.count[0]), int(cfg.civilians.count[1]))
	var weighted: Array = civ.types.filter(func(t): return float(t.weight) > 0.0)
	for i in count:
		_spawn_civilian(bank, civs, _pick(rng, weighted), rng)
	_spawn_civilian(bank, civs, data.civilian_types.manager, rng)
	_spawn_civilian(bank, civs, data.civilian_types.security_chief, rng)
	for i in guards:
		_spawn_civilian(bank, civs, data.civilian_types.guard, rng)
	for extra in civ.seeded_extras:
		var chance: float = extra.chance_by_stars[clampi(bank.stars, 1, 6) - 1]
		for i in int(extra.max):
			if rng.randf() < chance:
				_spawn_civilian(bank, civs, data.civilian_types[extra.type], rng)
	bank.civilians = civs

	# Escape routes this layout supports
	var present := VaultSolver.room_ids(bank)
	bank.escape_routes = data.escape_routes.values().filter(func(r):
		return r.start_requires_bank_rooms.all(func(id): return present.has(id))).map(func(r): return r.id)


static func _spawn_civilian(bank: Dictionary, civs: Array, type: Dictionary, rng: RandomNumberGenerator) -> void:
	var rooms: Array = bank.rooms.filter(func(r): return BankGenerator._shares(r.tags, type.spawn_tags))
	if rooms.is_empty():
		rooms = bank.rooms.filter(func(r): return "lobby" in r.tags)
	var r: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
	var c: Vector2i = r.cells[rng.randi_range(0, r.cells.size() - 1)]
	civs.append({"id": civs.size(), "type": type.id, "room": r.idx, "floor": r.floor, "cell": [c.x, c.y],
		"armed": rng.randf() < float(type.get("armed_chance", 0.0))})


static func _first_room(bank: Dictionary, room_id: String) -> int:
	for r in bank.rooms:
		if r.id == room_id:
			return r.idx
	return -1


static func _pick(rng: RandomNumberGenerator, options: Array) -> Dictionary:
	var total := 0.0
	for o in options:
		total += float(o.get("weight", 1))
	var roll := rng.randf() * total
	for o in options:
		roll -= float(o.get("weight", 1))
		if roll <= 0.0:
			return o
	return options.back()
