class_name BankValidator
extends RefCounted
## Checks a generated bank against seed_config.validation and the room rules.
## Returns a list of human-readable errors; empty means the bank is playable.


static func validate(bank: Dictionary, data: GameData) -> PackedStringArray:
	var errs: PackedStringArray = []
	var cfg := data.seed_config()
	var v: Dictionary = cfg.validation

	# Every cell filled
	if v.all_cells_filled:
		for fi in bank.floors.size():
			if bank.floors[fi].cells.has(-1):
				errs.append("floor %d has empty cells" % fi)

	# Required rooms present
	for fi in bank.floors.size():
		var f: Dictionary = bank.floors[fi]
		for room_id in cfg.required_per_floor.get(f.type, []):
			if not f.rooms.any(func(ri): return bank.rooms[ri].id == room_id):
				errs.append("floor %d (%s) missing %s" % [fi, f.type, room_id])
	var present := VaultSolver.room_ids(bank)
	for room_id in cfg.required_once.rooms:
		if not present.has(room_id):
			errs.append("building missing %s" % room_id)

	# Room rules
	for r in bank.rooms:
		var floor_tags := {}
		for ri in bank.floors[r.floor].rooms:
			for t in bank.rooms[ri].tags:
				floor_tags[t] = true
		for t in r.rules.get("requires_on_floor", []):
			if not floor_tags.has(t):
				errs.append("%s needs '%s' on its floor" % [r.id, t])
		for n in _neighbours(bank, r):
			if BankGenerator._shares(r.rules.get("never_adjacent", []), bank.rooms[n].tags):
				errs.append("%s may not touch %s" % [r.id, bank.rooms[n].id])
		if r.doors.size() > r.max_doors:
			errs.append("%s has %d doors, max %d" % [r.id, r.doors.size(), r.max_doors])

	# Reachability from the entries through doors and stairs/elevators
	if bank.entries.size() < int(v.min_entry_routes):
		errs.append("only %d entry routes" % bank.entries.size())
	if v.all_rooms_reachable:
		var unreachable := unreachable_rooms(bank)
		if not unreachable.is_empty():
			errs.append("%d unreachable rooms, e.g. %s" % [unreachable.size(), bank.rooms[unreachable[0]].id])

	# Vault solvable at least two ways
	if bank.has("vault"):
		if bank.vault.lock_solutions.size() < int(v.min_vault_lock_solutions):
			errs.append("vault lock %s has %d solutions" % [bank.vault.lock, bank.vault.lock_solutions.size()])
		if bank.vault.hazard_solutions.size() < int(v.min_vault_hazard_solutions):
			errs.append("hazard %s has %d solutions" % [bank.vault.hazard, bank.vault.hazard_solutions.size()])
	else:
		errs.append("no vault data")
	return errs


static func unreachable_rooms(bank: Dictionary) -> Array[int]:
	var adj := {}
	for r in bank.rooms:
		adj[r.idx] = []
	for d in bank.doors:
		if d.b >= 0:
			adj[d.a].append(d.b)
			adj[d.b].append(d.a)
	for link in bank.vertical_links:
		adj[link[0]].append(link[1])
		adj[link[1]].append(link[0])
	var seen := {}
	var queue: Array = bank.entries.map(func(e): return e.room)
	for q in queue:
		seen[q] = true
	while not queue.is_empty():
		var cur: int = queue.pop_back()
		for n in adj[cur]:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	var out: Array[int] = []
	for r in bank.rooms:
		if not seen.has(r.idx):
			out.append(r.idx)
	return out


static func _neighbours(bank: Dictionary, room: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var cells: Array = bank.floors[room.floor].cells
	for c in room.cells:
		for d in BankGenerator.DIRS.values():
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= bank.w or n.y >= bank.h:
				continue
			var ni: int = cells[n.y * bank.w + n.x]
			if ni != room.idx and ni >= 0 and ni not in out:
				out.append(ni)
	return out
