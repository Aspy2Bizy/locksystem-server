extends TestCase
## Cross-file consistency of res://data. Catches typos in ids before they become runtime bugs.


func test_all_files_load() -> void:
	check(data.errors.is_empty(), "data errors: %s" % ", ".join(data.errors))
	for f in ["roles", "weapons_gadgets", "difficulty_tiers", "room_prefabs", "vault_modules",
			"civilians", "escape_routes", "penalties", "seed_config", "modes"]:
		check(data.raw.has(f), "missing %s.json" % f)


func test_six_tiers() -> void:
	check_eq(data.tiers.size(), 6, "tier count")
	check(not data.tier(6).pvpve_allowed, "6 stars is PvE only")
	check(not data.tier(6).breakouts_allowed, "no breakouts at 6 stars")
	for s in range(1, 6):
		check(data.tier(s + 1).payout_multiplier > data.tier(s).payout_multiplier, "payout rises at %d" % (s + 1))
		check(data.tier(s + 1).scouting_reveal_fraction < data.tier(s).scouting_reveal_fraction, "scouting falls at %d" % (s + 1))
		check(data.tier(s + 1).hazard_damage_multiplier > data.tier(s).hazard_damage_multiplier, "hazards rise at %d" % (s + 1))


func test_role_gadgets_exist() -> void:
	for roles in [data.robber_roles, data.police_roles]:
		for r in roles.values():
			for g in r.gadgets:
				check(data.gadgets.has(g), "%s gadget %s not defined" % [r.id, g])
	for g in data.gadgets.values():
		for role in g.get("roles", []):
			check(role == "*" or data.robber_roles.has(role) or data.police_roles.has(role), "%s lists unknown role %s" % [g.id, role])


func test_recipes_and_parts() -> void:
	for r in data.recipes.values():
		check(data.gadgets.has(r.output), "recipe %s output %s not a gadget" % [r.id, r.output])
		for p in r.inputs:
			check(data.parts.has(p), "recipe %s needs unknown part %s" % [r.id, p])
	for p in data.parts.values():
		for room in p.found_in:
			check(data.rooms.has(room), "part %s found_in unknown room %s" % [p.id, room])


func test_vault_requirements_reference_real_things() -> void:
	var all: Array = []
	for l in data.vault_locks.values():
		all.append_array(l.solutions)
	for h in data.vault_hazards.values():
		all.append_array(h.solutions)
		check(h.solutions.size() >= 2, "hazard %s needs 2+ solutions" % h.id)
	for l in data.vault_locks.values():
		check(l.solutions.size() >= 2, "lock %s needs 2+ solutions" % l.id)
	for s in all:
		for room in s.requires.get("rooms", []):
			check(data.rooms.has(room), "solution %s needs unknown room %s" % [s.id, room])
		for p in s.requires.get("parts", []):
			check(data.parts.has(p), "solution %s needs unknown part %s" % [s.id, p])


func test_seed_config_rooms_exist() -> void:
	var cfg := data.seed_config()
	for ftype in cfg.required_per_floor:
		for room in cfg.required_per_floor[ftype]:
			check(data.rooms.has(room), "required room %s unknown" % room)
			if data.rooms.has(room):
				check(ftype in data.rooms[room].floors, "%s not allowed on %s" % [room, ftype])
	for room in cfg.required_once.rooms:
		check(data.rooms.has(room), "required_once %s unknown" % room)
	for e in cfg.floor_stack.order:
		var ftype: String = e.type
		var fillers := data.rooms.values().filter(func(r): return r.kind == "filler" and ftype in r.floors)
		check(not fillers.is_empty(), "no filler for floor type %s" % ftype)


func test_civilians_and_routes() -> void:
	var tags := {}
	for r in data.rooms.values():
		for t in r.tags:
			tags[t] = true
	for c in data.civilian_types.values():
		check(c.spawn_tags.any(func(t): return tags.has(t)), "civilian %s has no spawnable tag" % c.id)
	for e in data.raw.civilians.seeded_extras:
		check(data.civilian_types.has(e.type), "seeded extra %s unknown" % e.type)
		check_eq(e.chance_by_stars.size(), 6, "chance_by_stars for %s" % e.type)
	var inter := {}
	for i in data.raw.escape_routes.interceptions:
		inter[i.id] = true
	for r in data.escape_routes.values():
		for room in r.start_requires_bank_rooms:
			check(data.rooms.has(room), "route %s needs unknown room %s" % [r.id, room])
		for i in r.interceptions:
			check(inter.has(i), "route %s unknown interception %s" % [r.id, i])
